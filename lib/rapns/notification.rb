module Rapns
  class Notification < ActiveRecord::Base
    set_table_name "rapns_notifications"

    validates :device_token, :presence => true

    scope :ready_for_delivery, lambda { where(:delivered => false, :failed => false).merge(where("deliver_after IS NULL") | where("deliver_after < ?", Time.now)) }
  end
end