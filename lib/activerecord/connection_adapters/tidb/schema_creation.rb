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
            if options[:auto_random]
              sql << auto_random_sql(options[:auto_random])
            end
            sql
          end

          # TiDB executes version comments (/*T![feature_id] ... */) while
          # MySQL ignores them, so the generated DDL stays MySQL-compatible.
          # auto_random accepts true (server default shard bits), an Integer
          # (shard bits), or an Array of [shard_bits, range_bits].
          # Plain MySQL ignores TiDB version comments and would leave the
          # column without any id generation, so fall back to AUTO_INCREMENT.
          def auto_random_sql(auto_random)
            return " AUTO_INCREMENT" unless @conn.tidb?

            args =
              case auto_random
              when true
                ""
              when Array
                "(#{auto_random.join(', ')})"
              else
                "(#{auto_random})"
              end
            " /*T![auto_rand] AUTO_RANDOM#{args} */"
          end

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
