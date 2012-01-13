module Rapns
  module Daemon
    class C2dm
      def initialize(i)
        @name = "C2dm DeliveryHandler #{i}"
        @auth = Rapns::Daemon.configuration.c2dm.auth
        @push = Rapns::Daemon.configuration.c2dm.push
        @email = Rapns::Daemon.configuration.c2dm.email
        @password = Rapns::Daemon.configuration.c2dm.password
      end

      def send_notification(options)
       get_auth_token(@email, @password) unless @auth_token

       response = notificationRequest(options)

       # the response can be one of three codes:
       #   200 (success)
       #   401 (auth failed)
       #   503 (retry later with exponential backoff)
       #   see more documentation here:  http://code.google.com/android/c2dm/#testing
       if response.code.eql? "200"

         # look for the header 'Update-Client-Auth' in the response you get after sending
         # a message. It indicates that this is the token to be used for the next message to send.
         response.each_header do |key, value|
           @auth_token = value if key == "Update-Client-Auth"
         end
         return response

       elsif response.code.eql? "401"
         # auth failed.  Refresh auth key and requeue
         @auth_token = get_auth_token(@email, @password)
         response = notificationRequest(options)
         return response

       elsif response.code.eql? "503"
         # service un-available.
         return response
       end
     end

     private

     def get_auth_token(email, password)
       data = "accountType=HOSTED_OR_GOOGLE&Email=#{email}&Passwd=#{password}&service=ac2dm"
       headers = { "Content-type" => "application/x-www-form-urlencoded",
                   "Content-length" => "#{data.length}"}

       uri = URI.parse(@auth)
       http = Net::HTTP.new(uri.host, uri.port)
       http.use_ssl = true
       http.verify_mode = OpenSSL::SSL::VERIFY_NONE

       response, body = http.post(uri.path, data, headers)
       return body.split("\n")[2].gsub("Auth=", "")
     end

     def notificationRequest(options)
       data = {}
       options.each do |key, value|
         if [:registration_id, "registration_id", :collapse_key, "collapse_key"].include? key
           data[key] = value
         else
           data["data.#{key}"] = value
         end
       end

       data = data.map{|k, v| "&#{k}=#{URI.escape(v.to_s)}"}.reduce{|k, v| k + v}
       headers = { "Authorization" => "GoogleLogin auth=#{@auth_token}",
                   "Content-type" => "application/x-www-form-urlencoded",
                   "Content-length" => "#{data.length}" }
       uri = URI.parse(@push)
       http = Net::HTTP.new(uri.host, uri.port)
       http.use_ssl = true
       http.verify_mode = OpenSSL::SSL::VERIFY_NONE

       http.post(uri.path, data, headers)
     end
    end
  end
end