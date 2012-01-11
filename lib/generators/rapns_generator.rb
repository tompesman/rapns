class RapnsGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)

  def self.next_migration_number(path)
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def copy_migration
    migration_dir = File.expand_path("db/migrate")

    if !self.class.migration_exists?(migration_dir, 'create_rapns_notifications')
      migration_template "create_rapns_notifications.rb", "db/migrate/create_rapns_notifications.rb"
    end

    if !self.class.migration_exists?(migration_dir, 'create_rapns_feedback')
      migration_template "create_rapns_feedback.rb", "db/migrate/create_rapns_feedback.rb"
    end

    if !self.class.migration_exists?(migration_dir, 'add_c2dm_to_rapns_notifications.rb')
      migration_template "add_c2dm_to_rapns_notifications.rb.rb", "db/migrate/add_c2dm_to_rapns_notifications.rb.rb"
    end
  end

  def copy_config
    copy_file "rapns.yml", "config/rapns/rapns.yml"
  end
end