require "spec_helper"

describe Rapns::Daemon::DeliveryHandlerPoolC2dm do
  before do
    @handler = mock("DeliveryHandlerC2dm", :start => nil)
    Rapns::Daemon::DeliveryHandlerC2dm.stub(:new).and_return(@handler)
    @pool = Rapns::Daemon::DeliveryHandlerPoolC2dm.new(3)
    Rapns::Daemon.stub(:delivery_queue_c2dm).and_return(mock("Delivery queue", :push => nil))
  end

  it "should populate the pool" do
    Rapns::Daemon::DeliveryHandlerC2dm.should_receive(:new).exactly(3).times
    @pool.populate
  end

  it "waits for each handle to stop" do
    @pool.populate
    @handler.should_receive(:stop).exactly(3).times
    @pool.drain
  end
end