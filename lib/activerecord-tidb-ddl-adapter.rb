require "activerecord/tidb/ddl/adapter/version"
require "activerecord/tasks/tidb_database_tasks"

if defined?(Rails)
  module ActiveRecord
    module ConnectionAdapters
      class TidbRailtie < ::Rails::Railtie
        ActiveSupport.on_load :active_record do
          # Registering only stores the class name and require path; the
          # adapter file itself (which pulls in mysql2/abstract_mysql_adapter)
          # is required lazily by ActiveRecord::ConnectionAdapters.resolve
          # the first time a "tidb" connection is actually established.
          ActiveRecord::ConnectionAdapters.register("tidb", "ActiveRecord::ConnectionAdapters::TidbAdapter", "activerecord/connection_adapters/tidb_adapter")
          ActiveRecord::Tasks::DatabaseTasks.register_task(/tidb/, "ActiveRecord::Tasks::TiDBDatabaseTasks")
        end
      end
    end
  end
end
