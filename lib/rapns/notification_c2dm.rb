module Rapns
  class NotificationC2dm < Rapns::Notification
    validates :collapse_key, :presence => true

    def to_android
      {
        :registration_id => device_token,
        :message => alert,
        :extra_data => attributes_for_device,
        :collapse_key => collapse_key
      }
    end
  end
end