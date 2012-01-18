require 'thread'
require 'socket'
require 'pathname'
require 'net/http'
require 'net/https'

require 'rapns/daemon/interruptible_sleep'
require 'rapns/daemon/configuration'
require 'rapns/daemon/certificate'
require 'rapns/daemon/delivery_error'
require 'rapns/daemon/disconnection_error'
require 'rapns/daemon/pool'
require 'rapns/daemon/connection'
require 'rapns/daemon/connection_apns'
require 'rapns/daemon/connection_c2dm'
require 'rapns/daemon/connection_pool'
require 'rapns/daemon/database_reconnectable'
require 'rapns/daemon/delivery_queue'
require 'rapns/daemon/delivery_handler'
require 'rapns/daemon/delivery_handler_pool'
require 'rapns/daemon/feedback_receiver'
require 'rapns/daemon/feeder'
require 'rapns/daemon/logger'

module Rapns
  module Daemon
    class << self
      attr_accessor :logger, :configuration, :certificate, :delivery_queue,
      :connection_pool, :delivery_handler_pool, :foreground
      alias_method  :foreground?, :foreground
    end

    def self.start(environment, foreground)
      @foreground = foreground
      setup_signal_hooks

      self.configuration = Configuration.new(environment, File.join(Rails.root, 'config', 'rapns', 'rapns.yml'))
      configuration.load

      self.logger = Logger.new(:foreground => foreground, :airbrake_notify => configuration.airbrake_notify)

      self.certificate = Certificate.new(configuration.certificate)
      certificate.load

      self.delivery_queue = DeliveryQueue.new

      daemonize unless foreground?

      write_pid_file

      self.connection_pool = ConnectionPool.new
      self.connection_pool.populate(configuration.apns.push.connections, ConnectionApns)
      self.connection_pool.populate(configuration.c2dm.connections, ConnectionC2dm)

      self.delivery_handler_pool = DeliveryHandlerPool.new(configuration.apns.push.connections + configuration.c2dm.connections)
      delivery_handler_pool.populate

      logger.info('Ready')

      FeedbackReceiver.start if configuration.apns.push.connections > 0
      Feeder.start(foreground?)
    end

    protected

    def self.setup_signal_hooks
      @shutting_down = false

      ['SIGINT', 'SIGTERM'].each do |signal|
        Signal.trap(signal) do
          handle_shutdown_signal
        end
      end
    end

    def self.handle_shutdown_signal
      exit 1 if @shutting_down
      @shutting_down = true
      shutdown
    end

    def self.shutdown
      puts "\nShutting down..."
      Rapns::Daemon::FeedbackReceiver.stop
      Rapns::Daemon::Feeder.stop
      Rapns::Daemon.delivery_handler_pool.drain if Rapns::Daemon.delivery_handler_pool
      delete_pid_file
    end

    def self.daemonize
      exit if pid = fork
      Process.setsid
      exit if pid = fork

      Dir.chdir '/'
      File.umask 0000

      STDIN.reopen '/dev/null'
      STDOUT.reopen '/dev/null', 'a'
      STDERR.reopen STDOUT
    end

    def self.write_pid_file
      if !configuration.pid_file.blank?
        begin
          File.open(configuration.pid_file, 'w') do |f|
            f.puts $$
          end
        rescue SystemCallError => e
          logger.error("Failed to write PID to '#{configuration.pid_file}': #{e.inspect}")
        end
      end
    end

    def self.delete_pid_file
      pid_file = configuration.pid_file
      File.delete(pid_file) if !pid_file.blank? && File.exists?(pid_file)
    end
  end
end