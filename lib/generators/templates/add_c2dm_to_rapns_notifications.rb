class AddC2dmToRapnsNotifications < ActiveRecord::Migration
  def self.up
    # remove index for sqlite migration (index name is too long; the limit is 64 characters)
    remove_index :rapns_notifications, :name => "index_rapns_notifications_on_delivered_failed_deliver_after"
    change_table :rapns_notifications do |t|
      t.string    :collapse_key,    :null => true
      t.string    :type,            :null => false, :default => "apns"
      t.boolean   :delay_when_idle, :null => false, :default => false
    end

    # limit is not fixed:
    # - http://stackoverflow.com/questions/3868703/android-c2dm-registration-id-max-size
    # - http://groups.google.com/group/android-c2dm/browse_thread/thread/0141a5be624fc8c3
    change_column :rapns_notifications, :device_token, :string, :limit => 255

    # remove default value
    # can't add column to table with :null => false and no default, but you can change it afterwards
    change_column :rapns_notifications, :type, :string, :null => false, :default => "NULL"
    add_index :rapns_notifications, [:delivered, :failed, :deliver_after], :name => "index_rapns_notifications_on_delivered_failed_deliver_after"
  end

  def self.down
    remove_column :rapns_notifications, :type, :collapse_key, :delay_when_idle
    change_column :rapns_notifications, :device_token, :string, :limit => 64
  end
end
