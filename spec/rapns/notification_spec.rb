require "spec_helper"

describe Rapns::NotificationApns do
  it { should validate_presence_of(:device_token) }

  it "should validate the format of the device_token" do
    notification = Rapns::Notification.new(:device_token => "{$%^&*()}")
    notification.valid?.should be_true
  end
end

