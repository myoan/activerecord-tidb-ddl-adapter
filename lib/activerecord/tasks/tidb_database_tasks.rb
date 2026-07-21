# frozen_string_literal: true

require "active_record/tasks/mysql_database_tasks"

module ActiveRecord
  module Tasks # :nodoc:
    # Backs db:create, db:drop, db:purge, db:charset, db:collation, and
    # db:structure:dump/load for the "tidb" adapter. TiDB speaks the MySQL
    # wire protocol and DDL dialect, so CREATE/DROP DATABASE and the
    # mysqldump/mysql-based structure dump/load all work unchanged.
    class TiDBDatabaseTasks < MySQLDatabaseTasks # :nodoc:
    end
  end
end
