require "spec_helper"

describe Rapns::DeliveryError do
  let(:error) { Rapns::DeliveryError.new(4, 12, "Missing payload", "APNS") }

  it "returns an informative message" do
    error.message.should == "Unable to deliver notification 12, received APNS error 4 (Missing payload)"
  end

  it "returns the error code" do
    error.code.should == 4
  end
end