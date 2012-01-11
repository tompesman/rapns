require "spec_helper"

describe Rapns::Daemon::DeliveryHandlerC2dm do
  let(:delivery_handler_c2dm) { Rapns::Daemon::DeliveryHandlerC2dm.new(0) }

  before do
    @notification = Rapns::Notification.create!(:device_token => "a" * 64, :os => "android", :collapse_key => "key")
    Rapns::Daemon.stub(:delivery_queue_c2dm).and_return(Rapns::Daemon::DeliveryQueue.new)
    Rapns::Daemon.delivery_queue_c2dm.push(@notification)

    @c2dm = mock("C2dm", :send_notification => stub(:code => "200", :description => "description"))
    Rapns::Daemon::C2dm.stub(:new).and_return(@c2dm)

    configuration = mock("Configuration", :c2dm => stub(:auth => "auth", :push => "push", :email => "email", :password => "password"))
    Rapns::Daemon.stub(:configuration).and_return(configuration)
    @logger = mock("Logger", :error => nil, :info => nil)
    Rapns::Daemon.stub(:logger).and_return(@logger)
  end

  it "pushes a STOP instruction into the queue when told to stop" do
    Rapns::Daemon.delivery_queue_c2dm.should_receive(:push).with(Rapns::Daemon::DeliveryHandlerC2dm::STOP)
    delivery_handler_c2dm.stop
  end

  it "closes the connection when a STOP instruction is received" do
    Rapns::Daemon.delivery_queue_c2dm.push(Rapns::Daemon::DeliveryHandlerC2dm::STOP)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should pop a new notification from the delivery queue" do
    Rapns::Daemon.delivery_queue_c2dm.should_receive(:pop)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "does not attempt to deliver a notification when a STOP instruction is received" do
    Rapns::Daemon.delivery_queue_c2dm.pop # empty the queue
    delivery_handler_c2dm.should_not_receive(:deliver)
    Rapns::Daemon.delivery_queue_c2dm.push(Rapns::Daemon::DeliveryHandlerC2dm::STOP)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should send the binary version of the notification" do
    @notification.stub((:to_binary)).and_return("hi mom")
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should log the notification delivery" do
    Rapns::Daemon.logger.should_receive(:info).with("Notification #{@notification.id} delivered to #{@notification.device_token}")
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should mark the notification as delivered" do
    expect { delivery_handler_c2dm.send(:handle_next_notification); @notification.reload }.to change(@notification, :delivered).to(true)
  end

  it "should set the time the notification was delivered" do
    @notification.delivered_at.should be_nil
    delivery_handler_c2dm.send(:handle_next_notification)
    @notification.reload
    @notification.delivered_at.should be_kind_of(Time)
  end

  it "should not trigger validations when saving the notification" do
    @notification.should_receive(:save!).with(:validate => false)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should update notification with the ability to reconnect the database" do
    delivery_handler_c2dm.should_receive(:with_database_reconnect_and_retry)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should log if an error is raised when updating the notification" do
    e = StandardError.new("bork!")
    @notification.stub(:save!).and_raise(e)
    Rapns::Daemon.logger.should_receive(:error).with(e)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  it "should notify the delivery queue the notification has been processed" do
    Rapns::Daemon.delivery_queue_c2dm.should_receive(:notification_processed)
    delivery_handler_c2dm.send(:handle_next_notification)
  end

  describe "when delivery fails" do
    before do
      @c2dm = mock("C2dm", :send_notification => stub(:code => "503", :description => "description"))
      Rapns::Daemon::C2dm.stub(:new).and_return(@c2dm)
    end
  #   it "should update notification with the ability to reconnect the database" do
  #     delivery_handler_c2dm.should_receive(:with_database_reconnect_and_retry)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should set the notification as not delivered" do
  #     @notification.should_receive(:delivered=).with(false)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should set the notification delivered_at timestamp to nil" do
  #     @notification.should_receive(:delivered_at=).with(nil)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should set the notification as failed" do
  #     @notification.should_receive(:failed=).with(true)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
    it "should set the notification failed_at timestamp" do
      now = Time.now
      Time.stub(:now).and_return(now)
      @notification.should_receive(:failed_at=).with(now)
      delivery_handler_c2dm.send(:handle_next_notification)
    end
  #
  #   it "should set the notification error code" do
  #     @notification.should_receive(:error_code=).with(4)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should log the delivery error" do
  #     error = Rapns::DeliveryError.new(4, 12, "Missing payload")
  #     Rapns::DeliveryError.stub(:new => error)
  #     Rapns::Daemon.logger.should_receive(:error).with(error)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should set the notification error description" do
  #     @notification.should_receive(:error_description=).with("Missing payload")
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should skip validation when saving the notification" do
  #     @notification.should_receive(:save!).with(:validate => false)
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should read 6 bytes from the socket" do
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   it "should log that the connection is being reconnected" do
  #     Rapns::Daemon.logger.should_receive(:error).with("[DeliveryHandler 0] Error received, reconnecting...")
  #     delivery_handler_c2dm.send(:handle_next_notification)
  #   end
  #
  #   context "when the APNs disconnects without returning an error" do
  #     it 'should raise a DisconnectError error if the connection is closed without an error being returned' do
  #       error = Rapns::DisconnectionError.new
  #       Rapns::DisconnectionError.should_receive(:new).and_return(error)
  #       Rapns::Daemon.logger.should_receive(:error).with(error)
  #       delivery_handler_c2dm.send(:handle_next_notification)
  #     end
  #
  #     it 'does not set the error code on the notification' do
  #       @notification.should_receive(:error_code=).with(nil)
  #       delivery_handler_c2dm.send(:handle_next_notification)
  #     end
  #
  #     it 'sets the error descriptipon on the notification' do
  #       @notification.should_receive(:error_description=).with("APNs disconnected without returning an error.")
  #       delivery_handler_c2dm.send(:handle_next_notification)
  #     end
  #   end
  end
end