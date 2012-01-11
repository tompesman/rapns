module Rapns
  module Daemon
    class DeliveryHandlerPoolC2dm < Pool

      protected

      def new_object_for_pool(i)
        DeliveryHandlerC2dm.new(i)
      end

      def object_added_to_pool(object)
        object.start
      end

      def object_removed_from_pool(object)
        object.stop
      end
    end
  end
end