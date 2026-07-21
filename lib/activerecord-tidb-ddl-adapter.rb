require "activerecord/tidb/ddl/adapter/version"
require "activerecord/connection_adapters/tidb_adapter"
require "activerecord/tasks/tidb_database_tasks"

if defined?(Rails)
  module ActiveRecord
    module ConnectionAdapters
      class TidbRailtie < ::Rails::Railtie
        ActiveSupport.on_load :active_record do
          ActiveRecord::ConnectionAdapters.register("tidb", "ActiveRecord::ConnectionAdapters::TidbAdapter", "active_record/connection_adapters/tidb_adapter")
          ActiveRecord::Tasks::DatabaseTasks.register_task(/tidb/, "ActiveRecord::Tasks::TiDBDatabaseTasks")
        end
      end
    end
  end
end
