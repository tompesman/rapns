module Rapns
  module Daemon
    class ConnectionPool
      def initialize()
        @connections = []
        @mutex = Mutex.new
      end

      def populate(number, type)
        number.times do |i|
          c = type.new(i)
          c.connect
          checkin(c)
        end
      end

      def checkin(connection)
        @mutex.synchronize {@connections << connection}
      end

      def checkout(notification_type)
        # TODO: if a desired notification_type is not found nil is returned
        @mutex.synchronize {
          @connections.each_with_index {|c, i| return @connections.delete_at(i) if c.is_a? notification_type}; nil
        }
      end
    end
  end
end