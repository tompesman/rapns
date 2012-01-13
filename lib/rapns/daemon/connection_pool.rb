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

      def checkout(type)
        @mutex.synchronize {@connections.each {|c| return c if c.is_a? == type}; nil}
      end
    end
  end
end