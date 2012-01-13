module Rapns
  module Daemon
    class DeliveryHandler
      include DatabaseReconnectable

      attr_reader :name

      STOP = 0x666

      def initialize(i)
        @name = "DeliveryHandler #{i}"
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
        Rapns::Daemon.delivery_queue.push(STOP)
      end

      protected

      def handle_next_notification
        notification = Rapns::Daemon.delivery_queue.pop

        if notification == STOP
          return
        end

        begin
          if notification.is_a? NotificationApns
            connection = Rapns::Daemon.connection_pool.checkout(Rapns::Daemon::ConnectionApns)
          elsif notification.is_a? NotificationC2dm
            connection = Rapns::Daemon.connection_pool.checkout(Rapns::Daemon::ConnectionC2dm)
          end
          notification.deliver(connection)
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        ensure
          Rapns::Daemon.connection_pool.checkin(connection)
          Rapns::Daemon.delivery_queue.notification_processed
        end
      end
    end
  end
end