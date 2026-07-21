require "test_helper"
require "minitest/mock"

class GeneratedSqlTableClustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, clustered: true do |t|
      t.string "name"
    end
  end
end

class GeneratedSqlTableNonclustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, clustered: false do |t|
      t.string "name"
    end
  end
end

class GeneratedSqlColumnClustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: false do |t|
      t.bigint :id, primary_key: true, clustered: false, null: false
      t.string "name"
    end
  end
end

class GeneratedSqlAutoIdCache < ActiveRecord::Migration[7.2]
  def change
    create_table :users, auto_id_cache: 1 do |t|
      t.string "name"
    end
  end
end

class GeneratedSqlShardRowIdBits < ActiveRecord::Migration[7.2]
  def change
    create_table :users, clustered: false, shard_row_id_bits: 4, pre_split_regions: 2 do |t|
      t.string "name"
    end
  end
end

class GeneratedSqlTableOptions < ActiveRecord::Migration[7.2]
  def change
    create_table :users, charset: "utf8mb4", collation: "utf8mb4_bin", comment: "user table" do |t|
      t.string "name"
    end
  end
end

class GeneratedSqlAutoRandom < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: false do |t|
      t.bigint :id, primary_key: true, auto_random: 5, null: false
      t.string "name"
    end
  end
end

class GeneratedSqlAutoRandomDefault < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: false do |t|
      t.bigint :id, primary_key: true, auto_random: true, null: false
      t.string "name"
    end
  end
end

class GeneratedSqlWithoutConfig < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string "name"
    end
  end
end

class Activerecord::Tidb::GeneratedSqlTest < Minitest::Test
  attr_reader :connection

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    connection.drop_table :users if connection.table_exists?(:users)
  end

  # Captures the CREATE TABLE statement actually sent to the server, to
  # assert TiDB keywords are wrapped in version comments (MySQL-compatible).
  def capture_create_table_sql(migration)
    sqls = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sqls << payload[:sql]
    end
    migrate(migration)
    sqls.find { |sql| sql.start_with?("CREATE TABLE") && sql.include?("`users`") }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def test_table_level_clustered_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlTableClustered)
    assert_includes sql, "PRIMARY KEY /*T![clustered_index] CLUSTERED */"
  end

  def test_table_level_nonclustered_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlTableNonclustered)
    assert_includes sql, "PRIMARY KEY /*T![clustered_index] NONCLUSTERED */"
  end

  def test_column_level_clustered_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlColumnClustered)
    assert_includes sql, "PRIMARY KEY /*T![clustered_index] NONCLUSTERED */"
  end

  def test_auto_id_cache_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlAutoIdCache)
    assert_includes sql, "/*T![auto_id_cache] AUTO_ID_CACHE=1 */"
  end

  def test_shard_row_id_bits_and_pre_split_regions_use_version_comment
    sql = capture_create_table_sql(GeneratedSqlShardRowIdBits)
    assert_includes sql, "/*T! SHARD_ROW_ID_BITS=4 PRE_SPLIT_REGIONS=2 */"
  end

  def test_table_options_are_not_dropped
    sql = capture_create_table_sql(GeneratedSqlTableOptions)
    assert_includes sql, "DEFAULT CHARSET=utf8mb4"
    assert_includes sql, "COLLATE=utf8mb4_bin"
    assert_includes sql, "COMMENT 'user table'"
  end

  def test_auto_random_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlAutoRandom)
    assert_includes sql, "/*T![auto_rand] AUTO_RANDOM(5) */"
  end

  def test_auto_random_without_args_uses_version_comment
    sql = capture_create_table_sql(GeneratedSqlAutoRandomDefault)
    assert_includes sql, "/*T![auto_rand] AUTO_RANDOM */"
  end

  def test_auto_random_falls_back_to_auto_increment_on_mysql
    connection.stub(:tidb?, false) do
      sql = capture_create_table_sql(GeneratedSqlAutoRandom)
      assert_includes sql, "AUTO_INCREMENT"
      refute_includes sql, "AUTO_RANDOM"
    end
  end

  def test_auto_random_conflicts_with_auto_increment
    assert_raises(ArgumentError) do
      connection.create_table :users, id: false do |t|
        t.bigint :id, primary_key: true, auto_random: 5, auto_increment: true, null: false
      end
    end
  end

  def test_without_tidb_options_generates_plain_mysql_ddl
    sql = capture_create_table_sql(GeneratedSqlWithoutConfig)
    refute_includes sql, "/*T!"
  end
end
