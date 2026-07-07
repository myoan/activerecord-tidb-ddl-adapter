module ActiveRecord
  module ConnectionAdapters
    module TiDB
      PrimaryKeyDefinition = Struct.new(:name, :clustered) # :nodoc:

      class TableDefinition < MySQL::TableDefinition
        attr_reader :clustered, :shard_row_id_bits, :pre_split_regions, :auto_id_cache

        def initialize(conn, name, clustered: nil, shard_row_id_bits: nil, pre_split_regions: nil, auto_id_cache: nil, **)
          @auto_id_cache = auto_id_cache
          @clustered = clustered
          @pre_split_regions = pre_split_regions
          @shard_row_id_bits = shard_row_id_bits
          super(conn, name, **)
        end

        def set_primary_key(table_name, id, primary_key, **options)
          if id
            pk = primary_key || Base.get_primary_key(table_name.to_s.singularize)

            if id.is_a?(Hash)
              options.merge!(id.except(:type))
              id = id.fetch(:type, :primary_key)
            end

            if pk.is_a?(Array)
              primary_keys(pk, @clustered)
            else
              options[:clustered] = @clustered
              primary_key(pk, id, **options)
            end
          end
        end

        def primary_keys(name = nil, clustered = nil)
          @primary_keys = TiDB::PrimaryKeyDefinition.new(name, clustered) if name
          @primary_keys
        end

        def new_column_definition(name, type, **options)
          if @auto_id_cache
            options[:auto_id_cache] = @auto_id_cache
          end
          if @pre_split_regions
            options[:pre_split_regions] = @pre_split_regions
          end
          if @shard_row_id_bits
            options[:shard_row_id_bits] = @shard_row_id_bits
          end
          super(name, type, **options)
        end

        private
          def valid_column_definition_options
            super + [:auto_id_cache, :clustered, :pre_split_regions, :shard_row_id_bits]
          end
      end
    end
  end
end