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

    def as_hash
      json = ActiveSupport::OrderedHash.new
      json['registration_id'] = device_token
      json['collapse_key'] = collapse_key
      json['delay_when_idle'] = "1" if delay_when_idle == true
      json['data.message'] = alert if alert
      attributes_for_device.each { |k, v| json["data.#{k.to_s}"] = v.to_s } if attributes_for_device
      json
    end

    def to_message
      as_hash.map{|k, v| "&#{k}=#{URI.escape(v.to_s)}"}.reduce{|k, v| k + v}
    end

    def use_connection
      Rapns::Daemon::ConnectionC2dm
    end
  end
end