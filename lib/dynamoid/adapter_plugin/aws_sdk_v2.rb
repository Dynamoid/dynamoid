module Dynamoid
  module AdapterPlugin

    # The AwsSdkV2 adapter provides support for the aws-sdk version 2 for ruby.
    class AwsSdkV2
      attr_reader :table_cache

      # Establish the connection to DynamoDB.
      #
      # @return [Aws::DynamoDB::Client] the DynamoDB connection
      def connect!
        @client = if Dynamoid::Config.endpoint?
          Aws::DynamoDB::Client.new(endpoint: Dynamoid::Config.endpoint)
        else
          Aws::DynamoDB::Client.new
        end
        @table_cache = {}
      end

      # Return the client object.
      #
      # @since 1.0.0
      def client
        @client
      end

      # Get many items at once from DynamoDB. More efficient than getting each item individually.
      #
      # @example Retrieve IDs 1 and 2 from the table testtable
      #   Dynamoid::Adapter::AwsSdkV2.batch_get_item({'table1' => ['1', '2']})
      #
      # @param [Hash] table_ids the hash of tables and IDs to retrieve
      # @param [Hash] options to be passed to underlying BatchGet call
      #
      # @return [Hash] a hash where keys are the table names and the values are the retrieved items
      #
      # @since 1.0.0
      #
      # @todo: Provide support for passing options to underlying batch_get_item http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#batch_get_item-instance_method
      def batch_get_item(table_ids, options = {})
        request_items = Hash.new{|h, k| h[k] = []}
        return request_items if table_ids.all?{|k, v| v.empty?}

        table_ids.each do |t, ids|
          next if ids.empty?
          tbl = describe_table(t)
          hk  = tbl.hash_key.to_s
          rng = tbl.range_key.to_s

          keys = if rng.present?
            Array(ids).map do |h,r|
              { hk => h, rng => r }
            end
          else
            Array(ids).map do |id|
              { hk => id }
            end
          end

          request_items[t] = {
            keys: keys
          }
        end

        results = client.batch_get_item(
          request_items: request_items
        )

        ret = Hash.new([].freeze) # Default for tables where no rows are returned
        results.data[:responses].each do |table, rows|
          ret[table] = rows.collect { |r| result_item_to_hash(r) }
        end
        ret
      end

      # Delete many items at once from DynamoDB. More efficient than delete each item individually.
      #
      # @example Delete IDs 1 and 2 from the table testtable
      #   Dynamoid::Adapter::AwsSdk.batch_delete_item('table1' => ['1', '2'])
      #or
      #   Dynamoid::Adapter::AwsSdkV2.batch_delete_item('table1' => [['hk1', 'rk2'], ['hk1', 'rk2']]]))
      #
      # @param [Hash] options the hash of tables and IDs to delete
      #
      # @return nil
      #
      # @todo: Provide support for passing options to underlying delete_item http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#delete_item-instance_method
      def batch_delete_item(options)
        options.each_pair do |table_name, ids|
          table = describe_table(table_name)
          ids.each do |id|
            client.delete_item(table_name: table_name, key: key_stanza(table, *id))
          end
        end
        nil
      end

      # Create a table on DynamoDB. This usually takes a long time to complete.
      #
      # @param [String] table_name the name of the table to create
      # @param [Symbol] key the table's primary key (defaults to :id)
      # @param [Hash] options provide a range key here if the table has a composite key
      # @option options [Array<Dynamoid::Indexes::Index>] local_secondary_indexes
      # @option options [Array<Dynamoid::Indexes::Index>] global_secondary_indexes
      # @option options [Symbol] hash_key_type The type of the hash key
      # @since 1.0.0
      def create_table(table_name, key = :id, options = {})
        Dynamoid.logger.info "Creating #{table_name} table. This could take a while."
        read_capacity = options[:read_capacity] || Dynamoid::Config.read_capacity
        write_capacity = options[:write_capacity] || Dynamoid::Config.write_capacity

        secondary_indexes = options.slice(
          :local_secondary_indexes,
          :global_secondary_indexes
        )
        ls_indexes = options[:local_secondary_indexes]
        gs_indexes = options[:global_secondary_indexes]

        key_schema = {
          :hash_key_schema => { key => (options[:hash_key_type] || :string) },
          :range_key_schema => options[:range_key]
        }
        attribute_definitions = build_all_attribute_definitions(
          key_schema,
          secondary_indexes
        )
        key_schema = aws_key_schema(
          key_schema[:hash_key_schema],
          key_schema[:range_key_schema]
        )

        client_opts = {
          table_name: table_name,
          provisioned_throughput: {
            read_capacity_units: read_capacity,
            write_capacity_units: write_capacity
          },
          key_schema: key_schema,
          attribute_definitions: attribute_definitions
        }

        if ls_indexes.present?
          client_opts[:local_secondary_indexes] = ls_indexes.map do |index|
            index_to_aws_hash(index)
          end
        end

        if gs_indexes.present?
          client_opts[:global_secondary_indexes] = gs_indexes.map do |index|
            index_to_aws_hash(index)
          end
        end
        client.create_table(client_opts)
      rescue Aws::DynamoDB::Errors::ResourceInUseException => e
        Dynamoid.logger.error "Table #{table_name} cannot be created as it already exists"
      end

      # Removes an item from DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to delete
      # @param [Hash] options provide a range key here if the table has a composite key
      #
      # @since 1.0.0
      #
      # @todo: Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#delete_item-instance_method
      def delete_item(table_name, key, options = {})
        range_key = options[:range_key]
        conditions = options[:conditions]
        table = describe_table(table_name)
        client.delete_item(
          table_name: table_name,
          key: key_stanza(table, key, range_key),
          expected: expected_stanza(conditions)
        )
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
        raise Dynamoid::Errors::ConditionalCheckFailedException, e
      end

      # Deletes an entire table from DynamoDB.
      #
      # @param [String] table_name the name of the table to destroy
      #
      # @since 1.0.0
      def delete_table(table_name)
        client.delete_table(table_name: table_name)
        table_cache.clear
      end

      # @todo Add a DescribeTable method.

      # Fetches an item from DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to find
      # @param [Hash] options provide a range key here if the table has a composite key
      #
      # @return [Hash] a hash representing the raw item in DynamoDB
      #
      # @since 1.0.0
      #
      # @todo Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#get_item-instance_method
      def get_item(table_name, key, options = {})
        table    = describe_table(table_name)
        range_key = options.delete(:range_key)

        item = client.get_item(table_name: table_name,
          key: key_stanza(table, key, range_key)
        )[:item]
        item ? result_item_to_hash(item) : nil
      end

      # Edits an existing item's attributes, or adds a new item to the table if it does not already exist. You can put, delete, or add attribute values
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to find
      # @param [Hash] options provide a range key here if the table has a composite key
      #
      # @return new attributes for the record
      #
      # @todo Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#update_item-instance_method
      def update_item(table_name, key, options = {})
        range_key = options.delete(:range_key)
        conditions = options.delete(:conditions)
        table = describe_table(table_name)

        yield(iu = ItemUpdater.new(table, key, range_key))

        raise "non-empty options: #{options}" unless options.empty?
        begin
          result = client.update_item(table_name: table_name,
            key: key_stanza(table, key, range_key),
            attribute_updates: iu.to_h,
            expected: expected_stanza(conditions),
            return_values: "ALL_NEW"
          )
          result_item_to_hash(result[:attributes])
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          raise Dynamoid::Errors::ConditionalCheckFailedException, e
        end
      end

      # List all tables on DynamoDB.
      #
      # @since 1.0.0
      #
      # @todo Provide limit support http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#update_item-instance_method
      def list_tables
        client.list_tables[:table_names]
      end

      # Persists an item on DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [Object] object a hash or Dynamoid object to persist
      #
      # @since 1.0.0
      #
      # @todo: Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#put_item-instance_method
      def put_item(table_name, object, options = nil)
        item = {}

        object.each do |k, v|
          next if v.nil? || (v.respond_to?(:empty?) && v.empty?)
          item[k.to_s] = v
        end

        begin
          client.put_item(table_name: table_name,
            item: item,
            expected: expected_stanza(options)
          )
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          raise Dynamoid::Errors::ConditionalCheckFailedException, e
        end
      end

      # Query the DynamoDB table. This employs DynamoDB's indexes so is generally faster than scanning, but is
      # only really useful for range queries, since it can only find by one hash key at once. Only provide
      # one range key to the hash.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] opts the options to query the table with
      # @option opts [String] :hash_value the value of the hash key to find
      # @option opts [Number, Number] :range_between find the range key within this range
      # @option opts [Number] :range_greater_than find range keys greater than this
      # @option opts [Number] :range_less_than find range keys less than this
      # @option opts [Number] :range_gte find range keys greater than or equal to this
      # @option opts [Number] :range_lte find range keys less than or equal to this
      #
      # @return [Enumerable] matching items
      #
      # @since 1.0.0
      #
      # @todo Provide support for various other options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#query-instance_method
      def query(table_name, opts = {})
        table = describe_table(table_name)
        limit = opts.delete(:limit)
        batch = opts.delete(:batch_size)
        hk    = (opts[:hash_key].present? ? opts[:hash_key] : table.hash_key).to_s
        rng   = (opts[:range_key].present? ? opts[:range_key] : table.range_key).to_s
        q     = opts.slice(
                  :consistent_read,
                  :scan_index_forward,
                  :limit,
                  :select,
                  :index_name
                )

        opts.delete(:consistent_read)
        opts.delete(:scan_index_forward)
        opts.delete(:limit)
        opts.delete(:select)
        opts.delete(:index_name)

        opts.delete(:next_token).tap do |token|
          break unless token
          q[:exclusive_start_key] = {
            hk  => token[:hash_key_element],
            rng => token[:range_key_element]
          }
        end

        key_conditions = {
          hk => {
            # TODO: Provide option for other operators like NE, IN, LE, etc
            comparison_operator: EQ,
            attribute_value_list: [
              opts.delete(:hash_value).freeze
            ]
          }
        }

        opts.each_pair do |k, v|
          # TODO: ATM, only few comparison operators are supported, provide support for all operators
          next unless(op = RANGE_MAP[k])
          key_conditions[rng] = {
            comparison_operator: op,
            attribute_value_list: [
              opts.delete(k).freeze
            ].flatten # Flatten as BETWEEN operator specifies array of two elements
          }
        end

        q[:table_name]     = table_name
        q[:key_conditions] = key_conditions
        q[:limit] = batch || limit if batch || limit

        Enumerator.new { |y|
          # Batch loop, pulls multiple requests until done using the start_key
          loop do
            results = client.query(q)

            results.data[:items].each { |row| y << result_item_to_hash(row) }

            if((lk = results[:last_evaluated_key]) && batch)
              q[:exclusive_start_key] = lk
            else
              break
            end
          end

        }
      end

      EQ = "EQ".freeze

      RANGE_MAP = {
        range_greater_than: 'GT',
        range_less_than:    'LT',
        range_gte:          'GE',
        range_lte:          'LE',
        range_begins_with:  'BEGINS_WITH',
        range_between:      'BETWEEN',
        range_eq:           'EQ'
      }

      # Scan the DynamoDB table. This is usually a very slow operation as it naively filters all data on
      # the DynamoDB servers.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
      #
      # @return [Enumerable] matching items
      #
      # @since 1.0.0
      #
      # @todo: Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#scan-instance_method
      def scan(table_name, scan_hash, select_opts = {})
        limit = select_opts.delete(:limit)
        batch = select_opts.delete(:batch_size)

        request = { table_name: table_name }
        request[:limit] = batch || limit if batch || limit
        request[:scan_filter] = scan_hash.reduce({}) do |memo, kvp|
          memo[kvp[0].to_s] = {
            attribute_value_list: [kvp[1]],
            # TODO: Provide support for all comparison operators
            comparison_operator: EQ
          }
          memo
        end if scan_hash.present?

        Enumerator.new do |y|
          # Batch loop, pulls multiple requests until done using the start_key
          loop do
            results = client.scan(request)

            results.data[:items].each { |row| y << result_item_to_hash(row) }

            if((lk = results[:last_evaluated_key]) && batch)
              request[:exclusive_start_key] = lk
            else
              break
            end
          end
        end
      end


      #
      # Truncates all records in the given table
      #
      # @param [String] table_name the name of the table
      #
      # @since 1.0.0
      def truncate(table_name)
        table = describe_table(table_name)
        hk    = table.hash_key
        rk    = table.range_key

        scan(table_name, {}, {}).each do |attributes|
          opts = {}
          opts[:range_key] = attributes[rk.to_sym] if rk
          delete_item(table_name, attributes[hk], opts)
        end
      end

      def count(table_name)
        describe_table(table_name, true).item_count
      end

      protected

      STRING_TYPE  = "S".freeze
      NUM_TYPE     = "N".freeze
      BINARY_TYPE  = "B".freeze

      #Converts from symbol to the API string for the given data type
      # E.g. :number -> 'N'
      def api_type(type)
        case(type)
        when :string then STRING_TYPE
        when :number then NUM_TYPE
        when :binary then BINARY_TYPE
        else raise "Unknown type: #{type}"
        end
      end

      #
      # The key hash passed on get_item, put_item, delete_item, update_item, etc
      #
      def key_stanza(table, hash_key, range_key = nil)
        key = { table.hash_key.to_s => hash_key }
        key[table.range_key.to_s] = range_key if range_key
        key
      end

      #
      # @param [Hash] conditions Conditions to enforce on operation (e.g. { :if => { :count => 5 }, :unless_exists => ['id']})
      # @return an Expected stanza for the given conditions hash
      #
      def expected_stanza(conditions = nil)
        expected = Hash.new { |h,k| h[k] = {} }
        return expected unless conditions

        conditions[:unless_exists].try(:each) do |col|
          expected[col.to_s][:exists] = false
        end
        conditions[:if].try(:each) do |col,val|
          expected[col.to_s][:value] = val
        end

        expected
      end

      HASH_KEY  = "HASH".freeze
      RANGE_KEY = "RANGE".freeze

      #
      # New, semi-arbitrary API to get data on the table
      #
      def describe_table(table_name, reload = false)
        (!reload && table_cache[table_name]) || begin
          table_cache[table_name] = Table.new(client.describe_table(table_name: table_name).data)
        end
      end

      #
      # Converts a hash returned by get_item, scan, etc. into a key-value hash
      #
      def result_item_to_hash(item)
        {}.tap do |r|
          item.each { |k,v| r[k.to_sym] = v }
        end
      end

      # Converts a Dynamoid::Indexes::Index to an AWS API-compatible hash.
      # This resulting hash is of the form:
      #
      #   {
      #     index_name: String
      #     keys: {
      #       hash_key: aws_key_schema (hash)
      #       range_key: aws_key_schema (hash)
      #     }
      #     projection: {
      #       projection_type: (ALL, KEYS_ONLY, INCLUDE) String
      #       non_key_attributes: (optional) Array
      #     }
      #     provisioned_throughput: {
      #       read_capacity_units: Integer
      #       write_capacity_units: Integer
      #     }
      #   }
      #
      # @param [Dynamoid::Indexes::Index] index the index.
      # @return [Hash] hash representing an AWS Index definition.
      def index_to_aws_hash(index)
        key_schema = aws_key_schema(index.hash_key_schema, index.range_key_schema)

        hash = {
          :index_name => index.name,
          :key_schema => key_schema,
          :projection => {
            :projection_type => index.projection_type.to_s.upcase
          }
        }

        # If the projection type is include, specify the non key attributes
        if index.projection_type == :include
          hash[:projection][:non_key_attributes] = index.projected_attributes
        end

        # Only global secondary indexes have a separate throughput.
        if index.type == :global_secondary
          hash[:provisioned_throughput] = {
            :read_capacity_units => index.read_capacity,
            :write_capacity_units => index.write_capacity
          }
        end
        hash
      end

      # Converts hash_key_schema and range_key_schema to aws_key_schema
      # @param [Hash] hash_key_schema eg: {:id => :string}
      # @param [Hash] range_key_schema eg: {:created_at => :number}
      # @return [Array]
      def aws_key_schema(hash_key_schema, range_key_schema)
        schema = [{
          attribute_name: hash_key_schema.keys.first.to_s,
          key_type: HASH_KEY
        }]

        if range_key_schema.present?
          schema << {
            attribute_name: range_key_schema.keys.first.to_s,
            key_type: RANGE_KEY
          }
        end
        schema
      end

      # Builds aws attributes definitions based off of primary hash/range and
      # secondary indexes
      #
      # @param key_data
      # @option key_data [Hash] hash_key_schema - eg: {:id => :string}
      # @option key_data [Hash] range_key_schema - eg: {:created_at => :number}
      # @param [Hash] secondary_indexes
      # @option secondary_indexes [Array<Dynamoid::Indexes::Index>] :local_secondary_indexes
      # @option secondary_indexes [Array<Dynamoid::Indexes::Index>] :global_secondary_indexes
      def build_all_attribute_definitions(key_schema, secondary_indexes = {})
        ls_indexes = secondary_indexes[:local_secondary_indexes]
        gs_indexes = secondary_indexes[:global_secondary_indexes]

        attribute_definitions = []

        attribute_definitions << build_attribute_definitions(
          key_schema[:hash_key_schema],
          key_schema[:range_key_schema]
        )

        if ls_indexes.present?
          ls_indexes.map do |index|
            attribute_definitions << build_attribute_definitions(
              index.hash_key_schema,
              index.range_key_schema
            )
          end
        end

        if gs_indexes.present?
          gs_indexes.map do |index|
            attribute_definitions << build_attribute_definitions(
              index.hash_key_schema,
              index.range_key_schema
            )
          end
        end

        attribute_definitions.flatten!
        # uniq these definitions because range keys might be common between
        # primary and secondary indexes
        attribute_definitions.uniq!
        attribute_definitions
      end


      # Builds an attribute definitions based on hash key and range key
      # @params [Hash] hash_key_schema - eg: {:id => :string}
      # @params [Hash] range_key_schema - eg: {:created_at => :datetime}
      # @return [Array]
      def build_attribute_definitions(hash_key_schema, range_key_schema = nil)
        attrs = []

        attrs << attribute_definition_element(
          hash_key_schema.keys.first,
          hash_key_schema.values.first
        )

        if range_key_schema.present?
          attrs << attribute_definition_element(
            range_key_schema.keys.first,
            range_key_schema.values.first
          )
        end

        attrs
      end

      # Builds an aws attribute definition based on name and dynamoid type
      # @params [Symbol] name - eg: :id
      # @params [Symbol] dynamoid_type - eg: :string
      # @return [Hash]
      def attribute_definition_element(name, dynamoid_type)
        aws_type = api_type(dynamoid_type)

        {
          :attribute_name => name.to_s,
          :attribute_type => aws_type
        }
      end

      #
      # Represents a table. Exposes data from the "DescribeTable" API call, and also
      # provides methods for coercing values to the proper types based on the table's schema data
      #
      class Table
        attr_reader :schema

        #
        # @param [Hash] schema Data returns from a "DescribeTable" call
        #
        def initialize(schema)
          @schema = schema[:table]
        end

        def range_key
          @range_key ||= schema[:key_schema].find { |d| d[:key_type] == RANGE_KEY }.try(:attribute_name)
        end

        def range_type
          range_type ||= schema[:attribute_definitions].find { |d|
            d[:attribute_name] == range_key
          }.try(:fetch,:attribute_type, nil)
        end

        def hash_key
          @hash_key ||= schema[:key_schema].find { |d| d[:key_type] == HASH_KEY  }.try(:attribute_name).to_sym
        end

        #
        # Returns the API type (e.g. "N", "S") for the given column, if the schema defines it,
        # nil otherwise
        #
        def col_type(col)
          col = col.to_s
          col_def = schema[:attribute_definitions].find { |d| d[:attribute_name] == col.to_s }
          col_def && col_def[:attribute_type]
        end

        def item_count
          schema[:item_count]
        end
      end

      #
      # Mimics behavior of the yielded object on DynamoDB's update_item API (high level).
      #
      class ItemUpdater
        attr_reader :table, :key, :range_key

        def initialize(table, key, range_key = nil)
          @table = table; @key = key, @range_key = range_key
          @additions = {}
          @deletions = {}
          @updates   = {}
        end

        #
        # Adds the given values to the values already stored in the corresponding columns.
        # The column must contain a Set or a number.
        #
        # @param [Hash] vals keys of the hash are the columns to update, vals are the values to
        #               add. values must be a Set, Array, or Numeric
        #
        def add(values)
          @additions.merge!(values)
        end

        #
        # Removes values from the sets of the given columns
        #
        # @param [Hash] values keys of the hash are the columns, values are Arrays/Sets of items
        #               to remove
        #
        def delete(values)
          @deletions.merge!(values)
        end

        #
        # Replaces the values of one or more attributes
        #
        def set(values)
          @updates.merge!(values)
        end

        #
        # Returns an AttributeUpdates hash suitable for passing to the V2 Client API
        #
        def to_h
          ret = {}

          @additions.each do |k,v|
            ret[k.to_s] = {
              action: ADD,
              value: v
            }
          end
          @deletions.each do |k,v|
            ret[k.to_s] = {
              action: DELETE,
              value: v
            }
          end
          @updates.each do |k,v|
            ret[k.to_s] = {
              action: PUT,
              value: v
            }
          end

          ret
        end

        ADD    = "ADD".freeze
        DELETE = "DELETE".freeze
        PUT    = "PUT".freeze
      end
    end
  end
end
