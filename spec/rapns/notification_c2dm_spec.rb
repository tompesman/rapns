require "spec_helper"

describe Rapns::NotificationC2dm do
  it { should validate_presence_of(:device_token) }
  it { should validate_presence_of(:collapse_key) }

  it "should validate the format of the device_token" do
    notification = Rapns::NotificationC2dm.new(:device_token => "abcdefghijklmnopqrstuvwxyz", :collapse_key => "KEY")
    notification.valid?.should be_true

    notification.to_message.should eql("&registration_id=abcdefghijklmnopqrstuvwxyz&collapse_key=KEY")
  end

  it "should use correct connection" do
    Rapns::NotificationC2dm.new().use_connection().should eql(Rapns::Daemon::ConnectionC2dm)
  end

 context "returns error" do
    before do
      configuration = mock("Configuration", :c2dm => stub(:auth => "auth-url", :push => "push-url", :connections => 2, :email => "email@gmail.com", :password => "secret"))
      Rapns::Daemon.stub(:configuration).and_return(configuration)
      @connection = Rapns::Daemon::ConnectionC2dm.new(1)
      @connection.stub(:write)
      @logger = mock("Logger", :error => nil)
      Rapns::Daemon.stub(:logger).and_return(@logger)
      @notification = Rapns::NotificationC2dm.new(:device_token => "abcdefghijklmnopqrstuvwxyz", :collapse_key => "KEY")
    end

    it "should check_for_errors 200 + error in body" do
      response = mock("Response", :code => "200", :body => "Error=bla")
      @connection.stub(:response).and_return(response)

      @connection.write(@notification.to_message)
      expect { @notification.check_for_error(@connection) }.to raise_error(Rapns::DeliveryError)
    end

    it "should check_for_errors 401" do
      response = mock("Response", :code => "401", :description => "Description here")
      @connection.stub(:response).and_return(response)

      @connection.write(@notification.to_message)
      expect { @notification.check_for_error(@connection) }.to raise_error(Rapns::DeliveryError)
    end

    it "should check_for_errors 503" do
      response = mock("Response", :code => "503", :description => "Description here")
      @connection.stub(:response).and_return(response)

      @connection.write(@notification.to_message)
      expect { @notification.check_for_error(@connection) }.to raise_error(Rapns::DeliveryError)
    end
  end
end

