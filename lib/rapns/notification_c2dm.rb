module Rapns
  class NotificationC2dm < Rapns::Notification
    validates :collapse_key, :presence => true

    def check_for_error(connection)
      response = connection.response

      if response.code.eql? "200" and response.body[/Error=(.*)/, 1]
        error = Rapns::DeliveryError.new(response.code, id, response.body[/Error=(.*)/, 1], "C2DM")
        Rapns::Daemon.logger.error("[#{connection.name}] Error received, reconnecting...")
        raise error if error
      elsif !response.code.eql? "200"
        error = Rapns::DeliveryError.new(response.code, id, response.description, "C2DM")
        Rapns::Daemon.logger.error("[#{connection.name}] Error received, reconnecting...")
        raise error if error
      end
    end

    def to_message
      data = {}
      options = {
        :registration_id => device_token,
        :message => alert,
        :extra_data => attributes_for_device,
        :collapse_key => collapse_key
      }

      options.each do |key, value|
        if [:registration_id, :collapse_key].include? key
          data[key] = value
        else
          data["data.#{key}"] = value
        end
      end

      data.map{|k, v| "&#{k}=#{URI.escape(v.to_s)}"}.reduce{|k, v| k + v}
    end

    def use_connection
      Rapns::Daemon::ConnectionC2dm
    end
  end
end