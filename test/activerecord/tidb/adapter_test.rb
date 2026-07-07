require "test_helper"

class SetInColumn < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: false do |t|
      t.bigint :id, primary_key: true, clustered: false, null: false
      t.string "name"
    end
  end
end

class SingleKeyNonclustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, clustered: false do |t|
      t.string "name"
    end
  end
end

class SingleKeyClustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, clustered: true do |t|
      t.string "name"
    end
  end
end

class SingleKeyWithoutConfig < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string "name"
    end
  end
end

class MultiKeyNonclustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, primary_key: [:id, :name], clustered: false do |t|
      t.bigint "id", null: false
      t.string "name"
    end
  end
end

class MultiKeyClustered < ActiveRecord::Migration[7.2]
  def change
    create_table :users, primary_key: [:id, :name], clustered: true do |t|
      t.bigint "id", null: false
      t.string "name"
    end
  end
end

class MultiKeyWithoutConfig < ActiveRecord::Migration[7.2]
  def change
    create_table :users, primary_key: [:id, :name] do |t|
      t.bigint "id", null: false
      t.string "name"
    end
  end
end

class AutoRandomInColumn < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: false do |t|
      t.bigint :id, primary_key: true, auto_random: 5, null: false
      t.string "name"
    end
  end
end

class Activerecord::Tidb::AdapterTest < Minitest::Test
  attr_reader :connection

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    connection.drop_table :users if connection.table_exists?(:users)
  end

  def test_set_in_column
    migrate(SetInColumn)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL AUTO_INCREMENT,
        `name` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`) /*T![clustered_index] NONCLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_single_key_nonclustered
    migrate(SingleKeyNonclustered)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL AUTO_INCREMENT,
        `name` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`) /*T![clustered_index] NONCLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_single_key_clustered
    migrate(SingleKeyClustered)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL AUTO_INCREMENT,
        `name` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`) /*T![clustered_index] CLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_single_key_without_config
    migrate(SingleKeyWithoutConfig)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL AUTO_INCREMENT,
        `name` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`) /*T![clustered_index] CLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_multiple_key_nonclustered
    migrate(MultiKeyNonclustered)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL,
        `name` varchar(255) NOT NULL,
        PRIMARY KEY (`id`,`name`) /*T![clustered_index] NONCLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_multiple_key_clustered
    migrate(MultiKeyClustered)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL,
        `name` varchar(255) NOT NULL,
        PRIMARY KEY (`id`,`name`) /*T![clustered_index] CLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_auto_random_in_column
    migrate(AutoRandomInColumn)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL /*T![auto_rand] AUTO_RANDOM(5) */,
        `name` varchar(255) DEFAULT NULL,
        PRIMARY KEY (`id`) /*T![clustered_index] CLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end

  def test_multiple_key_without_config
    migrate(MultiKeyWithoutConfig)

    result = connection.execute("SHOW CREATE TABLE users")
    _, query = result.first
    expected_query = <<~QUERY.strip
      CREATE TABLE `users` (
        `id` bigint NOT NULL,
        `name` varchar(255) NOT NULL,
        PRIMARY KEY (`id`,`name`) /*T![clustered_index] CLUSTERED */
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
    QUERY
    assert_equal expected_query, query
  end
end
