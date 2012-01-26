require "spec_helper"

describe Rapns::Daemon::FeedbackReceiver, 'check_for_feedback' do

  it 'instantiates a new connection with a name' do
    Rapns::Daemon.configuration = stub(:apns => stub(:feedback => stub(:host => 'feedback.push.apple.com', :port => 2196, :poll => 60)))
    f = Rapns::Daemon::ConnectionApns.new
    f.name.should eql("FeedbackReceiver")
  end

  context "with stub" do
    let(:connection) { stub(:connect => nil, :read => nil, :close => nil) }
    let(:logger) { stub(:error => nil, :info => nil) }

    before do
      Rapns::Daemon::FeedbackReceiver.stub(:interruptible_sleep)
      Rapns::Daemon.logger = logger
      Rapns::Daemon::ConnectionApns.stub(:new => connection)
      Rapns::Feedback.stub(:create!)
      Rapns::Daemon.configuration = stub(:apns => stub(:feedback => stub(:host => 'feedback.push.apple.com', :port => 2196, :poll => 60)))
      Rapns::Daemon::FeedbackReceiver.instance_variable_set("@stop", false)
    end

    def stub_connection_read_with_tuple
      connection.unstub(:read)

      def connection.read(bytes)
        if !@called
          @called = true
          "N\xE3\x84\r\x00 \x83OxfU\xEB\x9F\x84aJ\x05\xAD}\x00\xAF1\xE5\xCF\xE9:\xC3\xEA\a\x8F\x1D\xA4M*N\xB0\xCE\x17"
        end
      end
    end

    it 'instantiates a new connection' do
      Rapns::Daemon::ConnectionApns.should_receive(:new).with()
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'connects to the feeback service' do
      connection.should_receive(:connect)
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'closes the connection' do
      connection.should_receive(:close)
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'reads from the connection' do
      connection.should_receive(:read).with(38)
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'logs the feedback' do
      stub_connection_read_with_tuple
      Rapns::Daemon.logger.should_receive(:info).with("[FeedbackReceiver] Delivery failed at 2011-12-10 16:08:45 UTC for 834f786655eb9f84614a05ad7d00af31e5cfe93ac3ea078f1da44d2a4eb0ce17")
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'creates the feedback' do
      stub_connection_read_with_tuple
      Rapns::Feedback.should_receive(:create!).with(:failed_at => Time.at(1323533325), :device_token => '834f786655eb9f84614a05ad7d00af31e5cfe93ac3ea078f1da44d2a4eb0ce17')
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'logs errors' do
      error = StandardError.new('bork!')
      connection.stub(:read).and_raise(error)
      Rapns::Daemon.logger.should_receive(:error).with(error)
      Rapns::Daemon::FeedbackReceiver.check_for_feedback
    end

    it 'sleeps for the feedback poll period' do
      Rapns::Daemon::FeedbackReceiver.stub(:check_for_feedback)
      Rapns::Daemon::FeedbackReceiver.should_receive(:interruptible_sleep).with(60).at_least(:once)
      Thread.stub(:new).and_yield
      Rapns::Daemon::FeedbackReceiver.stub(:loop).and_yield
      Rapns::Daemon::FeedbackReceiver.start
    end

    it 'checks for feedback when started' do
      Rapns::Daemon::FeedbackReceiver.should_receive(:check_for_feedback).at_least(:once)
      Thread.stub(:new).and_yield
      Rapns::Daemon::FeedbackReceiver.stub(:loop).and_yield
      Rapns::Daemon::FeedbackReceiver.start
    end

    it 'interrupts sleep when stopped' do
      Rapns::Daemon::FeedbackReceiver.stub(:check_for_feedback)
      Rapns::Daemon::FeedbackReceiver.should_receive(:interrupt_sleep)
      Rapns::Daemon::FeedbackReceiver.stop
    end
  end
end