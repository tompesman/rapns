class AddC2dmToRapnsNotifications < ActiveRecord::Migration
  def self.up
    change_table :rapns_notifications do |t|
      t.string    :collapse_key,    :null => true
      t.string    :os,              :null => false, :default => "ios"
      t.boolean   :delay_when_idle, :null => false, :default => false
    end

    # limit is not fixed:
    # - http://stackoverflow.com/questions/3868703/android-c2dm-registration-id-max-size
    # - http://groups.google.com/group/android-c2dm/browse_thread/thread/0141a5be624fc8c3
    change_column :rapns_notifications, :device_token, :string, :limit => 255
    # remove default value
    # can't add column to table with :null => false and no default, but you can change it afterwards
    change_column :rapns_notifications, :os, :string, :null => false, :default => "NULL"
  end

  def self.down
    remove_column :rapns_notifications, :os, :collapse_key, :delay_when_idle
    change_column :rapns_notifications, :device_token, :string, :limit => 64
  end
end
