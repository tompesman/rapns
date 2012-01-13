module Rapns
  class NotificationC2dm < Rapns::Notification
    validates :collapse_key, :presence => true

    def check_for_error(connection)
      response = connection.response
      unless response.code.eql? "200"
        error = Rapns::DeliveryError.new(response.code, id, response.description)
        Rapns::Daemon.logger.error("[#{@name}] Error received, reconnecting...")
        raise error if error
      end
    end

    def to_message
      {
        :registration_id => device_token,
        :message => alert,
        :extra_data => attributes_for_device,
        :collapse_key => collapse_key
      }
    end
  end
end