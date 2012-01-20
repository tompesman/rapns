require 'active_record'
require 'active_record/errors'
require 'rapns/daemon/database_reconnectable'
module Rapns
  class Notification < ActiveRecord::Base
    include Rapns::Daemon::DatabaseReconnectable
    set_table_name "rapns_notifications"

    validates :device_token, :presence => true

    scope :ready_for_delivery, lambda { where('delivered = ? AND failed = ? AND (deliver_after IS NULL OR deliver_after < ?)', false, false, Time.now) }

    def deliver(connection)
      begin
        connection.write(self.to_message)
        check_for_error(connection)

        # this code makes no sense in the rails environment, but it does in the daemon
        with_database_reconnect_and_retry(connection.name) do
          self.delivered = true
          self.delivered_at = Time.now
          self.save!(:validate => false)
        end

        Rapns::Daemon.logger.info("Notification #{id} delivered to #{device_token}")
      rescue Rapns::DeliveryError, Rapns::DisconnectionError => error
        handle_delivery_error(error, connection)
        raise
      end
    end

    private

    def handle_delivery_error(error, connection)
      # this code makes no sense in the rails environment, but it does in the daemon
      with_database_reconnect_and_retry(connection.name) do
        self.delivered = false
        self.delivered_at = nil
        self.failed = true
        self.failed_at = Time.now
        self.error_code = error.code
        self.error_description = error.description
        self.save!(:validate => false)
      end
    end
  end
end