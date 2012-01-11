module Rapns
  module Daemon
    class Feeder
      extend DatabaseReconnectable
      extend InterruptibleSleep

      def self.name
        "Feeder"
      end

      def self.start(foreground)
        reconnect_database unless foreground

        loop do
          break if @stop
          enqueue_notifications
          interruptible_sleep Rapns::Daemon.configuration.apns.push.poll
        end
      end

      def self.stop
        @stop = true
        interrupt_sleep
      end

      protected

      def self.enqueue_notifications
        begin
          with_database_reconnect_and_retry do
            if Rapns::Daemon.delivery_queue.notifications_processed?
              Rapns::Notification.ready_for_delivery.each do |notification|
                if notification.os == 'ios'
                  Rapns::Daemon.delivery_queue.push(notification)
                elsif notification.os == 'android'
                  Rapns::Daemon.delivery_queue_c2dm.push(notification)
                end
              end
            end
          end
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        end
      end
    end
  end
end