require "spec_helper"

describe Rapns::Daemon::Configuration do
  module Rails
  end

  let(:config) do
    {
      "airbrake_notify" => false,
      "certificate" => "production.pem",
      "certificate_password" => "abc123",
      "pid_file" => "rapns.pid",
      "push" => {
        "port" => 123,
        "host" => "localhost",
        "poll" => 4,
        "connections" => 6
      },
      "feedback" => {
        "port" => 123,
        "host" => "localhost",
        "poll" => 30,
      },
      "c2dm" => {
        "auth" => "https://www.google.com/accounts/ClientLogin",
        "push" => "https://android.apis.google.com/c2dm/send",
        "email" => "email",
        "password" => "password"
      }
    }
  end

  before do
    Rails.stub(:root).and_return("/rails_root")
  end

  it 'opens the config from the given path' do
    YAML.stub(:load => {"production" => config})
    fd = stub(:read => nil)
    File.should_receive(:open).with("/tmp/rapns-non-existant-file").and_yield(fd)
    config = Rapns::Daemon::Configuration.new("production", "/tmp/rapns-non-existant-file")
    config.stub(:ensure_config_exists)
    config.load
  end

  it 'reads the config as YAML' do
    YAML.should_receive(:load).and_return({"production" => config})
    fd = stub(:read => nil)
    File.stub(:open).and_yield(fd)
    config = Rapns::Daemon::Configuration.new("production", "/tmp/rapns-non-existant-file")
    config.stub(:ensure_config_exists)
    config.load
  end

  it "should raise an error if the configuration file does not exist" do
    expect { Rapns::Daemon::Configuration.new("production", "/tmp/rapns-non-existant-file").load }.to raise_error(Rapns::ConfigurationError, "/tmp/rapns-non-existant-file does not exist. Have you run 'rails g rapns'?")
  end

  it "should raise an error if the environment is not configured" do
    configuration = Rapns::Daemon::Configuration.new("development", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => {}})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "Configuration for environment 'development' not defined in /some/config.yml")
  end

  it "should raise an error if the push host is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["push"]["host"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "'push.host' not defined for environment 'production' in /some/config.yml. You may need to run 'rails g rapns' after updating.")
  end

  it "should raise an error if the push port is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["push"]["port"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "'push.port' not defined for environment 'production' in /some/config.yml. You may need to run 'rails g rapns' after updating.")
  end

  it "should raise an error if the feedback host is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["feedback"]["host"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "'feedback.host' not defined for environment 'production' in /some/config.yml. You may need to run 'rails g rapns' after updating.")
  end

  it "should raise an error if the feedback port is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["feedback"]["port"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "'feedback.port' not defined for environment 'production' in /some/config.yml. You may need to run 'rails g rapns' after updating.")
  end

  it "should raise an error if the certificate is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config.except("certificate")})
    expect { configuration.load }.to raise_error(Rapns::ConfigurationError, "'certificate' not defined for environment 'production' in /some/config.yml. You may need to run 'rails g rapns' after updating.")
  end

  it "should set the push host" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.host.should == "localhost"
  end

  it "should set the push port" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.port.should == 123
  end

  it "should set the feedback port" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.feedback.port.should == 123
  end

  it "should set the feedback host" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.feedback.host.should == "localhost"
  end

  it "should set the airbrake notify flag" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.airbrake_notify?.should == false
  end

  it "should default the airbrake notify flag to true if not set" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config.except("airbrake_notify")})
    configuration.load
    configuration.airbrake_notify?.should == true
  end

  it "should set the push poll frequency" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.poll.should == 4
  end

  it "should set the feedback poll frequency" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.feedback.poll.should == 30
  end

  it "should default the push poll frequency to 2 if not set" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["push"]["poll"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.poll.should == 2
  end

  it "should default the feedback poll frequency to 60 if not set" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["feedback"]["poll"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.feedback.poll.should == 60
  end

  it "should set the number of push connections" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.connections.should == 6
  end

  it "should default the number of push connections to 3 if not set" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    config["push"]["connections"] = nil
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.push.connections.should == 3
  end

  it "should set the certificate password" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.certificate_password.should == "abc123"
  end

  it "should set the certificate password to a blank string if it is not configured" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config.except("certificate_password")})
    configuration.load
    configuration.certificate_password.should == ""
  end

  it "should set the certificate, with absolute path" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.certificate.should == "/rails_root/config/rapns/production.pem"
  end

  it "should keep the absolute path of the certificate if it has one" do
    config["certificate"] = "/different_path/to/production.pem"
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.certificate.should == "/different_path/to/production.pem"
  end

  it "should set the PID file path" do
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.pid_file.should == "/rails_root/rapns.pid"
  end

  it "should keep the absolute path of the PID file if it has one" do
    config["pid_file"] = "/some/absolue/path/rapns.pid"
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.pid_file.should == "/some/absolue/path/rapns.pid"
  end

  it "should return nil if no PID file was set" do
    config["pid_file"] = ""
    configuration = Rapns::Daemon::Configuration.new("production", "/some/config.yml")
    configuration.stub(:read_config).and_return({"production" => config})
    configuration.load
    configuration.pid_file.should be_nil
  end
end