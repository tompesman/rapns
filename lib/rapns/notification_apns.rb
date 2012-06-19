module Rapns
  class NotificationApns < Rapns::Notification

    SELECT_TIMEOUT = 0.5
    ERROR_TUPLE_BYTES = 6
    APN_ERRORS = {
      1 => "Processing error",
      2 => "Missing device token",
      3 => "Missing topic",
      4 => "Missing payload",
      5 => "Missing token size",
      6 => "Missing topic size",
      7 => "Missing payload size",
      8 => "Invalid token",
      255 => "None (unknown error)"
    }

    validates :badge, :numericality => true, :allow_nil => true
    validates :expiry, :numericality => true, :presence => true

    validates_with Rapns::DeviceTokenFormatValidator
    validates_with Rapns::BinaryNotificationValidator

    def device_token=(token)
      write_attribute(:device_token, token.delete(" <>")) if !token.nil?
    end

    def alert=(alert)
      if alert.is_a?(Hash)
        write_attribute(:alert, MultiJson.dump(alert))
      else
        write_attribute(:alert, alert)
      end
    end

    def alert
      string_or_json = read_attribute(:alert)
      MultiJson.load(string_or_json) rescue string_or_json
    end

    def as_json
      json = ActiveSupport::OrderedHash.new
      json['aps'] = ActiveSupport::OrderedHash.new
      json['aps']['alert'] = alert if alert
      json['aps']['badge'] = badge if badge
      json['aps']['sound'] = sound if sound
      attributes_for_device.each { |k, v| json[k.to_s] = v.to_s } if attributes_for_device
      json
    end

    # This method conforms to the enhanced binary format.
    # http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW4
    def to_message(options = {})
      id_for_pack = options[:for_validation] ? 0 : id
      [1, id_for_pack, expiry, 0, 32, device_token, payload_size, payload].pack("cNNccH*na*")
    end

    def use_connection
      Rapns::Daemon::ConnectionApns
    end

    def payload
      MultiJson.dump(as_json)
    end

    def payload_size
      payload.bytesize
    end

    private

    def check_for_error(connection)
      if connection.select(SELECT_TIMEOUT)
        error = nil

        if tuple = connection.read(ERROR_TUPLE_BYTES)
          cmd, code, notification_id = tuple.unpack("ccN")

          description = APN_ERRORS[code.to_i] || "Unknown error. Possible rapns bug?"
          error = Rapns::DeliveryError.new(code, notification_id, description, "APNS")
        else
          error = Rapns::DisconnectionError.new
        end

        begin
          Rapns::Daemon.logger.error("[#{connection.name}] Error received, reconnecting...")
          connection.reconnect
        ensure
          raise error if error
        end
      end
    end
  end
end