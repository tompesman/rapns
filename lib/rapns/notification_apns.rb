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
        write_attribute(:alert, ActiveSupport::JSON.encode(alert))
      else
        write_attribute(:alert, alert)
      end
    end

    def alert
      string_or_json = read_attribute(:alert)
      ActiveSupport::JSON.decode(string_or_json) rescue string_or_json
    end

    def attributes_for_device=(attrs)
      raise ArgumentError, "attributes_for_device must be a Hash" if !attrs.is_a?(Hash)
      write_attribute(:attributes_for_device, ActiveSupport::JSON.encode(attrs))
    end

    def attributes_for_device
      ActiveSupport::JSON.decode(read_attribute(:attributes_for_device)) if read_attribute(:attributes_for_device)
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
    def to_binary(options = {})
      id_for_pack = options[:for_validation] ? 0 : id
      json = as_json.to_json
      [1, id_for_pack, expiry, 0, 32, device_token, 0, json.size, json].pack("cNNccH*cca*")
    end

    def deliver(notification)
      begin
        @connection.write(notification.to_binary)
        check_for_error

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

    def check_for_error
      if @connection.select(SELECT_TIMEOUT)
        error = nil

        if tuple = @connection.read(ERROR_TUPLE_BYTES)
          cmd, code, notification_id = tuple.unpack("ccN")

          description = APN_ERRORS[code.to_i] || "Unknown error. Possible rapns bug?"
          error = Rapns::DeliveryError.new(code, notification_id, description)
        else
          error = Rapns::DisconnectionError.new
        end

        begin
          Rapns::Daemon.logger.error("[#{@name}] Error received, reconnecting...")
          @connection.reconnect
        ensure
          raise error if error
        end
      end
    end

  end
end