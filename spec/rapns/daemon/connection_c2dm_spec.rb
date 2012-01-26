require "spec_helper"

describe Rapns::Daemon::ConnectionC2dm do

  before do
    configuration = mock("Configuration", :c2dm => stub(:auth => "https://www.google.com/accounts/ClientLogin", :push => "https://android.apis.google.com/c2dm/send", :connections => 2, :email => "email@gmail.com", :password => "secret"))
    Rapns::Daemon.stub(:configuration).and_return(configuration)
    @logger = mock("Logger", :error => nil, :info => nil)
    Rapns::Daemon.stub(:logger).and_return(@logger)

    stub_request(:post, "https://www.google.com/accounts/ClientLogin").
      with(:body => {"accountType"=>"HOSTED_OR_GOOGLE", "Email"=>"email@gmail.com", "Passwd"=>"secret", "service"=>"ac2dm", "source"=>"rapns"},
      :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 200, :body => "Auth=AUTHTOKEN", :headers => {})

    stub_request(:post, "https://android.apis.google.com/c2dm/send").
      with(:body => {"Bla"=>true},
      :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 200, :body => "", :headers => {})

    @connection = Rapns::Daemon::ConnectionC2dm.new(1)
  end

  it "should open a connection" do
    Rapns::Daemon.logger.should_receive(:info).with("[ConnectionC2dm 1] Connected to https://android.apis.google.com/c2dm/send")
    @connection.connect
  end

  it "should fetch an authentication token" do
    @connection.connect
    WebMock.should have_requested(:post, "https://www.google.com/accounts/ClientLogin").with(:body => "accountType=HOSTED_OR_GOOGLE&Email=email@gmail.com&Passwd=secret&service=ac2dm&source=rapns", :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/x-www-form-urlencoded'})
  end

  it "should post a notification" do
    @connection.connect
    @connection.write("Bla")
    WebMock.should have_requested(:post, "https://android.apis.google.com/c2dm/send").with(:body => "Bla", :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'})
  end

  it "should write data and receive a 200" do
    @connection.connect
    @connection.write("Bla")
    @connection.response.code.should eql("200")
  end

  it "should write data and receive a 200 and a Update-Client-Auth header" do
    Rapns::Daemon.logger.should_receive(:info).with("[ConnectionC2dm 1] Received new authentication token")
    stub_request(:post, "https://android.apis.google.com/c2dm/send").
      with(:body => {"Bla"=>true},
      :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 200, :body => "", :headers => {"Update-Client-Auth" => "NEWTOKEN"})

    @connection.connect
    @connection.write("Bla")
    @connection.response.code.should eql("200")

    WebMock.should have_requested(:post, "https://android.apis.google.com/c2dm/send").with(:body => "Bla", :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'})

    stub_request(:post, "https://android.apis.google.com/c2dm/send").
      with(:body => {"Bla"=>true},
      :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=NEWTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 200, :body => "", :headers => {})

    @connection.write("Bla")
    @connection.response.code.should eql("200")

    WebMock.should have_requested(:post, "https://android.apis.google.com/c2dm/send").with(:body => "Bla", :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=NEWTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'})
  end

  it "should write data and receive a 401" do
    @connection.connect
    stub_request(:post, "https://android.apis.google.com/c2dm/send").
      with(:body => {"Bla"=>true},
      :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 401, :body => "", :headers => {})
    @connection.write("Bla")
    @connection.response.code.should eql("401")

    WebMock.should have_requested(:post, "https://www.google.com/accounts/ClientLogin").with(:body => "accountType=HOSTED_OR_GOOGLE&Email=email@gmail.com&Passwd=secret&service=ac2dm&source=rapns", :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/x-www-form-urlencoded'}).twice
  end

  it "should write data and receive a 503" do
    @connection.connect
    stub_request(:post, "https://android.apis.google.com/c2dm/send").
      with(:body => {"Bla"=>true},
      :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'}).
      to_return(:status => 503, :body => "", :headers => {})
    @connection.write("Bla")
    @connection.response.code.should eql("503")

    WebMock.should have_requested(:post, "https://www.google.com/accounts/ClientLogin").with(:body => "accountType=HOSTED_OR_GOOGLE&Email=email@gmail.com&Passwd=secret&service=ac2dm&source=rapns", :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/x-www-form-urlencoded'})
  end

  it "should reconnect after 5 minutes" do
    now = Time.now
    Time.stub!(:now).and_return(now - 6.minutes)
    @connection.connect

    Time.stub!(:now).and_return(now)
    @connection.write("Bla")

    WebMock.should have_requested(:post, "https://android.apis.google.com/c2dm/send").with(:body => "Bla", :headers => {'Accept'=>'*/*', 'Authorization'=>'GoogleLogin auth=AUTHTOKEN', 'Content-Length'=>'3', 'Content-Type'=>'application/x-www-form-urlencoded'})
  end
end