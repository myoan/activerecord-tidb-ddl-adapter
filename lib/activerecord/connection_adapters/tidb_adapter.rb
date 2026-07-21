# frozen_string_literal: true

require "activerecord/tidb/ddl/adapter/version"
require "active_support"
require "active_record"

require "active_record/connection_adapters"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/mysql2_adapter"
require "active_record/connection_adapters/abstract_mysql_adapter"

require "activerecord/connection_adapters/tidb/schema_creation"
require "activerecord/connection_adapters/tidb/schema_definitions"
require "activerecord/connection_adapters/tidb/schema_statements"

module ActiveRecord
  module ConnectionAdapters
    class TidbAdapter < Mysql2Adapter
      ADAPTER_NAME = "TiDB"
      
      include TiDB::SchemaStatements

      class << self
        def new_client(config)
          ::Mysql2::Client.new(config)
        rescue ::Mysql2::Error => error
          raise ActiveRecord::ConnectionNotEstablished, error.message
        end

        private
          def initialize_type_map(m)
            super
          end
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }

      def initialize(...)
        super
        @config[:flags] ||= 0
        if @config[:flags].kind_of? Array
          @config[:flags].push "FOUND_ROWS"
        else
          @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
        end
        @connection_parameters ||= @config
      end

      def supports_clustered_index?
        database_version >= "5.0.0"  # TiDB 5.0+でサポート
      end

      # The tidb adapter can also connect to a plain MySQL server; some
      # features (e.g. AUTO_RANDOM) need to know which one they talk to.
      def tidb?
        return @tidb unless @tidb.nil?
        @tidb = full_version.include?("TiDB")
      end

      def supports_json?
        true
      end

      def supports_comments?
        true
      end

      def supports_comments_in_create?
        true
      end

      private
        def connect
          @raw_connection = self.class.new_client(@connection_parameters)
        rescue ConnectionNotEstablished => ex
          raise ex.set_pool(@pool)
        end

        def full_version
          database_version.full_version_string
        end

        def get_full_version
          any_raw_connection.server_info[:version]
        end
    end

    ActiveSupport.run_load_hooks(:active_record_tidbadapter, TidbAdapter)
  end
end
