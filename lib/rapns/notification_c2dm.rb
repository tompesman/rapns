module Rapns
  class NotificationC2dm < Rapns::Notification
    validates :collapse_key, :presence => true

    def deliver(notification)
      begin
        response = @c2dm.send_notification(notification.to_android)
        check_for_error(response, notification.id)

        with_database_reconnect_and_retry do
          notification.delivered = true
          notification.delivered_at = Time.now
          notification.save!(:validate => false)
        end

        Rapns::Daemon.logger.info("Notification #{notification.id} delivered to #{notification.device_token}")
      rescue Rapns::DeliveryError, Rapns::DisconnectionError => error
        handle_delivery_error(notification, error)
        raise
      end
    end

    def handle_delivery_error(notification, error)
      with_database_reconnect_and_retry do
        notification.delivered = false
        notification.delivered_at = nil
        notification.failed = true
        notification.failed_at = Time.now
        notification.error_code = error.code
        notification.error_description = error.description
        notification.save!(:validate => false)
      end
    end

    def check_for_error(response, notification_id)
      unless response.code.eql? "200"
        error = Rapns::DeliveryError.new(response.code, notification_id, response.description)
        Rapns::Daemon.logger.error("[#{@name}] Error received, reconnecting...")
        raise error if error
      end
    end

    def to_android
      {
        :registration_id => device_token,
        :message => alert,
        :extra_data => attributes_for_device,
        :collapse_key => collapse_key
      }
    end
  end
end