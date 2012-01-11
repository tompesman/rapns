require "spec_helper"

describe Rapns::NotificationC2dm do
  it { should validate_presence_of(:device_token) }

  it "should validate the format of the device_token" do
    notification = Rapns::NotificationC2dm.new(:device_token => "{$%^&*()}")
    notification.valid?.should be_false
  end
end

