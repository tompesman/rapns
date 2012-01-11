module Rapns
  module Daemon
    class DeliveryHandlerC2dm
      include DatabaseReconnectable

      STOP = 0x666

      attr_reader :name

      def initialize(i)
        @name = "DeliveryHandlerC2dm #{i}"
        @c2dm = C2dm.new(i)
      end

      def start
        Thread.new do
          loop do
            break if @stop
            handle_next_notification
          end
        end
      end

      def stop
        @stop = true
        Rapns::Daemon.delivery_queue_c2dm.push(STOP)
      end

      protected

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

      def handle_next_notification
        notification = Rapns::Daemon.delivery_queue_c2dm.pop

        if notification == STOP
          return
        end

        begin
          deliver(notification)
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        ensure
          Rapns::Daemon.delivery_queue_c2dm.notification_processed
        end
      end
    end
  end
end