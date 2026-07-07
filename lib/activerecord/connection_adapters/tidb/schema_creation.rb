module ActiveRecord
  module ConnectionAdapters
    module TiDB
      class SchemaCreation < MySQL::SchemaCreation
        private
          def add_table_options!(create_sql, o)
            super
            if o.auto_id_cache
              create_sql << " /*T![auto_id_cache] AUTO_ID_CACHE=#{o.auto_id_cache} */"
            end
            shard_options = []
            shard_options << "SHARD_ROW_ID_BITS=#{o.shard_row_id_bits}" if o.shard_row_id_bits
            shard_options << "PRE_SPLIT_REGIONS=#{o.pre_split_regions}" if o.pre_split_regions
            unless shard_options.empty?
              create_sql << " /*T! #{shard_options.join(' ')} */"
            end
            create_sql
          end

          def visit_PrimaryKeyDefinition(o)
            sql = "PRIMARY KEY"
            sql << " (#{o.name.map { |name| quote_column_name(name) }.join(', ')})"
            sql << clustered_index_sql(o.clustered)
            sql
          end

          def add_column_options!(sql, options)
            sql = super(sql, options)
            if options[:primary_key] == true
              sql << clustered_index_sql(options[:clustered])
            end
            sql
          end

          # TiDB executes version comments (/*T![feature_id] ... */) while
          # MySQL ignores them, so the generated DDL stays MySQL-compatible.
          def clustered_index_sql(clustered)
            case clustered
            when true
              " /*T![clustered_index] CLUSTERED */"
            when false
              " /*T![clustered_index] NONCLUSTERED */"
            else
              ""
            end
          end
      end
    end
  end
end
