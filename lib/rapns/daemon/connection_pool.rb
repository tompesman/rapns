module Rapns
  module Daemon
    class ConnectionPool
      def initialize()
        @connections = Hash.new
      end

      def populate(number, type)
        @connections[type.to_s] = Queue.new
        number.times do |i|
          c = type.new(i+1)
          c.connect
          checkin(c)
        end
      end

      def checkin(connection)
        @connections[connection.class.to_s].push(connection)
      end

      def checkout(notification_type)
        @connections[notification_type.to_s].pop
      end
    end
  end
end