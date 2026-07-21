require "test_helper"

class Activerecord::Tidb::DatabaseTasksTest < Minitest::Test
  DATABASE_NAME = "tidb_adapter_database_tasks_test"

  CONNECTION_OPTIONS = {
    host: "127.0.0.1",
    port: 4000,
    username: "root",
    password: ""
  }.freeze

  def db_config
    ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test", "primary", CONNECTION_OPTIONS.merge(adapter: "tidb", database: DATABASE_NAME)
    )
  end

  def tasks
    ActiveRecord::Tasks::TiDBDatabaseTasks.new(db_config)
  end

  def teardown
    ActiveRecord::Base.establish_connection(**CONNECTION_OPTIONS, adapter: "tidb", database: nil)
    ActiveRecord::Base.lease_connection.drop_database(DATABASE_NAME)
  ensure
    ActiveRecord::Base.establish_connection(**CONNECTION_OPTIONS, adapter: "tidb", database: "tidb_test")
  end

  def test_tidb_adapter_is_registered_for_database_tasks
    assert_equal ActiveRecord::Tasks::TiDBDatabaseTasks,
      ActiveRecord::Tasks::DatabaseTasks.send(:class_for_adapter, "tidb")
  end

  def test_create_and_drop_database
    tasks.create
    ActiveRecord::Base.establish_connection(db_config)
    assert_equal DATABASE_NAME, ActiveRecord::Base.lease_connection.current_database

    tasks.drop
    ActiveRecord::Base.establish_connection(**CONNECTION_OPTIONS, adapter: "tidb", database: nil)
    refute_includes ActiveRecord::Base.lease_connection.select_values("SHOW DATABASES"), DATABASE_NAME
  end

  def test_purge_recreates_an_empty_database
    tasks.create
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.lease_connection.create_table(:widgets) { |t| t.string :name }
    assert ActiveRecord::Base.lease_connection.table_exists?(:widgets)

    tasks.purge
    ActiveRecord::Base.establish_connection(db_config)
    refute ActiveRecord::Base.lease_connection.table_exists?(:widgets)
  end

  def test_charset_and_collation
    tasks.create
    ActiveRecord::Base.establish_connection(db_config)

    assert_equal "utf8mb4", tasks.charset
    assert_equal "utf8mb4_bin", tasks.collation
  end
end
