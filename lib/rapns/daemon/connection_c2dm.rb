module Rapns
  module Daemon
    class ConnectionError < StandardError; end

    class ConnectionC2dm < Connection
      attr_reader :response, :name

      def initialize(i)
        @name = "ConnectionC2dm #{i}"
        @auth = Rapns::Daemon.configuration.c2dm.auth
        @push = Rapns::Daemon.configuration.c2dm.push
        @email = Rapns::Daemon.configuration.c2dm.email
        @password = Rapns::Daemon.configuration.c2dm.password
      end

      def connect
        @auth_token = fetch_auth_token
        @last_use = Time.now
        uri = URI.parse(@push)
        @connection = open_http(uri.host, uri.port)
        @connection.start
        Rapns::Daemon.logger.info("[#{@name}] Connected to #{@push}")
      end

      def write(data)
        @response = notificationRequest(data)

        # the response can be one of three codes:
        #   200 (success)
        #   401 (auth failed)
        #   503 (retry later with exponential backoff)
        #   see more documentation here:  http://code.google.com/android/c2dm/#testing
        if @response.code.eql? "200"
          # look for the header 'Update-Client-Auth' in the response you get after sending
          # a message. It indicates that this is the token to be used for the next message to send.
          @response.header.each_header do |key, value|
            if key.capitalize == "Update-Client-Auth".capitalize
              Rapns::Daemon.logger.info("[#{@name}] Received new authentication token")
              @auth_token = value
            end
          end

        elsif @response.code.eql? "401"
          # auth failed.  Refresh auth key and requeue
          @auth_token = fetch_auth_token
          @response = notificationRequest(data)

        elsif response.code.eql? "503"
          # service un-available.
        end
      end

      private

      def open_http(host, port)
        http = Net::HTTP.new(host, port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        return http
      end

      def fetch_auth_token
        data = "accountType=HOSTED_OR_GOOGLE&Email=#{@email}&Passwd=#{@password}&service=ac2dm&source=rapns"
        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        uri = URI.parse(@auth)
        http = open_http(uri.host, uri.port)
        response = http.post(uri.path, data, headers)
        return response.body[/Auth=(.*)/, 1]
      end

      def notificationRequest(data)
        headers = { "Authorization" => "GoogleLogin auth=#{@auth_token}",
                   "Content-type" => "application/x-www-form-urlencoded",
                   "Content-length" => "#{data.length}" }
        uri = URI.parse(@push)

        # Timeout on the http connection is 5 minutes, reconnect after 5 minutes
        if @last_use + 5.minutes < Time.now
          @connection.finish
          @connection.start
        end
        @last_use = Time.now

        @connection.post(uri.path, data, headers)
      end
    end
  end
end