module ActiveRecord
  module ConnectionAdapters
    module TiDB
      module SchemaStatements
        def schema_creation
          TiDB::SchemaCreation.new(self)
        end

        def create_table_definition(name, **options)
          TiDB::TableDefinition.new(self, name, **options)
        end

        def valid_table_definition_options # :nodoc:
          super + [:auto_id_cache, :clustered, :pre_split_regions, :shard_row_id_bits]
        end

        # TiDB refuses to DROP COLUMN a column that is part of a composite
        # (multi-column) index: "MySQL::Error: can't drop column to with
        # composite index covered or Primary Key covered now", unlike
        # MySQL/InnoDB which just narrows the index. Work around it by
        # dropping the affected composite indexes before the DROP COLUMN
        # and re-adding them without the removed column(s) afterwards.
        def remove_column(table_name, column_name, type = nil, **options)
          rebuild_composite_indexes_without_columns(table_name, [column_name]) do
            super
          end
        end

        def remove_columns(table_name, *column_names, type: nil, **options)
          rebuild_composite_indexes_without_columns(table_name, column_names) do
            super
          end
        end

        private
          def rebuild_composite_indexes_without_columns(table_name, column_names)
            dropped = column_names.map(&:to_s)

            affected_indexes = indexes(table_name).select do |index|
              index.columns.is_a?(Array) &&
                index.columns.size > 1 &&
                (index.columns.map(&:to_s) & dropped).any?
            end

            affected_indexes.each { |index| remove_index(table_name, name: index.name) }

            result = yield

            affected_indexes.each do |index|
              remaining_columns = index.columns.reject { |column| dropped.include?(column.to_s) }
              next if remaining_columns.empty?

              index_options = { name: index.name, unique: index.unique }
              index_options[:using] = index.using if index.using
              index_options[:comment] = index.comment if index.comment

              lengths = index.lengths.slice(*remaining_columns)
              index_options[:length] = lengths if lengths.present?

              orders = index.orders.slice(*remaining_columns)
              index_options[:order] = orders if orders.present?

              add_index(table_name, remaining_columns, **index_options)
            end

            result
          end
      end
    end
  end
end