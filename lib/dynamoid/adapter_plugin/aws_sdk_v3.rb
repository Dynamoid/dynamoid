# frozen_string_literal: true

require_relative 'aws_sdk_v3/query'
require_relative 'aws_sdk_v3/scan'
require_relative 'aws_sdk_v3/create_table'
require_relative 'aws_sdk_v3/item_updater'
require_relative 'aws_sdk_v3/table'
require_relative 'aws_sdk_v3/until_past_table_status'

module Dynamoid
  module AdapterPlugin
    # The AwsSdkV3 adapter provides support for the aws-sdk version 2 for ruby.
    class AwsSdkV3
      EQ = 'EQ'
      RANGE_MAP = {
        range_greater_than: 'GT',
        range_less_than:    'LT',
        range_gte:          'GE',
        range_lte:          'LE',
        range_begins_with:  'BEGINS_WITH',
        range_between:      'BETWEEN',
        range_eq:           'EQ'
      }.freeze

      # Don't implement NULL and NOT_NULL because it doesn't make seanse -
      # we declare schema in models
      FIELD_MAP = {
        eq:           'EQ',
        ne:           'NE',
        gt:           'GT',
        lt:           'LT',
        gte:          'GE',
        lte:          'LE',
        begins_with:  'BEGINS_WITH',
        between:      'BETWEEN',
        in:           'IN',
        contains:     'CONTAINS',
        not_contains: 'NOT_CONTAINS'
      }.freeze
      HASH_KEY  = 'HASH'
      RANGE_KEY = 'RANGE'
      STRING_TYPE  = 'S'
      NUM_TYPE     = 'N'
      BINARY_TYPE  = 'B'
      TABLE_STATUSES = {
        creating: 'CREATING',
        updating: 'UPDATING',
        deleting: 'DELETING',
        active: 'ACTIVE'
      }.freeze
      PARSE_TABLE_STATUS = lambda { |resp, lookup = :table|
        # lookup is table for describe_table API
        # lookup is table_description for create_table API
        #   because Amazon, damnit.
        resp.send(lookup).table_status
      }
      BATCH_WRITE_ITEM_REQUESTS_LIMIT = 25

      CONNECTION_CONFIG_OPTIONS = %i[endpoint region http_continue_timeout http_idle_timeout http_open_timeout http_read_timeout].freeze

      attr_reader :table_cache

      # Establish the connection to DynamoDB.
      #
      # @return [Aws::DynamoDB::Client] the DynamoDB connection
      def connect!
        @client = Aws::DynamoDB::Client.new(connection_config)
        @table_cache = {}
      end

      def connection_config
        @connection_hash = {}

        (Dynamoid::Config.settings.compact.keys & CONNECTION_CONFIG_OPTIONS).each do |option|
          @connection_hash[option] = Dynamoid::Config.send(option)
        end
        if Dynamoid::Config.access_key?
          @connection_hash[:access_key_id] = Dynamoid::Config.access_key
        end
        if Dynamoid::Config.secret_key?
          @connection_hash[:secret_access_key] = Dynamoid::Config.secret_key
        end

        # https://github.com/aws/aws-sdk-ruby/blob/master/gems/aws-sdk-core/lib/aws-sdk-core/plugins/logging.rb
        # https://github.com/aws/aws-sdk-ruby/blob/master/gems/aws-sdk-core/lib/aws-sdk-core/log/formatter.rb
        formatter = Aws::Log::Formatter.new(':operation | Request :http_request_body | Response :http_response_body')
        @connection_hash[:logger] = Dynamoid::Config.logger
        @connection_hash[:log_level] = :debug
        @connection_hash[:log_formatter] = formatter

        @connection_hash
      end

      # Return the client object.
      #
      # @since 1.0.0
      def client
        @client
      end

      # Puts multiple items in one table
      #
      # If optional block is passed it will be called for each written batch of items, meaning once per batch.
      # Block receives boolean flag which is true if there are some unprocessed items, otherwise false.
      #
      # @example Saves several items to the table testtable
      #   Dynamoid::AdapterPlugin::AwsSdkV3.batch_write_item('table1', [{ id: '1', name: 'a' }, { id: '2', name: 'b'}])
      #
      # @example Pass block
      #   Dynamoid::AdapterPlugin::AwsSdkV3.batch_write_item('table1', items) do |bool|
      #     if bool
      #       puts 'there are unprocessed items'
      #     end
      #   end
      #
      # @param [String] table_name the name of the table
      # @param [Array]  items to be processed
      # @param [Hash]   additional options
      # @param [Proc]   optional block
      #
      # See:
      # * http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
      # * http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#batch_write_item-instance_method
      def batch_write_item(table_name, objects, options = {})
        items = objects.map { |o| sanitize_item(o) }

        begin
          while items.present?
            batch = items.shift(BATCH_WRITE_ITEM_REQUESTS_LIMIT)
            requests = batch.map { |item| { put_request: { item: item } } }

            response = client.batch_write_item(
              {
                request_items: {
                  table_name => requests
                },
                return_consumed_capacity: 'TOTAL',
                return_item_collection_metrics: 'SIZE'
              }.merge!(options)
            )

            yield(response.unprocessed_items.present?) if block_given?

            if response.unprocessed_items.present?
              items += response.unprocessed_items[table_name].map { |r| r.put_request.item }
            end
          end
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          raise Dynamoid::Errors::ConditionalCheckFailedException, e
        end
      end

      # Get many items at once from DynamoDB. More efficient than getting each item individually.
      #
      # If optional block is passed `nil` will be returned and the block will be called for each read batch of items,
      # meaning once per batch.
      #
      # Block receives parameters:
      # * hash with items like `{ table_name: [items]}`
      # * and boolean flag is true if there are some unprocessed keys, otherwise false.
      #
      # @example Retrieve IDs 1 and 2 from the table testtable
      #   Dynamoid::AdapterPlugin::AwsSdkV3.batch_get_item('table1' => ['1', '2'])
      #
      # @example Pass block to receive each batch
      #   Dynamoid::AdapterPlugin::AwsSdkV3.batch_get_item('table1' => ids) do |hash, bool|
      #     puts hash['table1']
      #
      #     if bool
      #       puts 'there are unprocessed keys'
      #     end
      #   end
      #
      # @param [Hash] table_ids the hash of tables and IDs to retrieve
      # @param [Hash] options to be passed to underlying BatchGet call
      # @param [Proc] optional block can be passed to handle each batch of items
      #
      # @return [Hash] a hash where keys are the table names and the values are the retrieved items
      #
      #  See:
      #  * http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#batch_get_item-instance_method
      #
      # @since 1.0.0
      #
      # @todo: Provide support for passing options to underlying batch_get_item
      def batch_get_item(table_ids, options = {})
        request_items = Hash.new { |h, k| h[k] = [] }
        return request_items if table_ids.all? { |_k, v| v.blank? }

        ret = Hash.new([].freeze) # Default for tables where no rows are returned

        table_ids.each do |t, ids|
          next if ids.blank?

          ids = Array(ids).dup
          tbl = describe_table(t)
          hk  = tbl.hash_key.to_s
          rng = tbl.range_key.to_s

          while ids.present?
            batch = ids.shift(Dynamoid::Config.batch_size)

            request_items = Hash.new { |h, k| h[k] = [] }

            keys = if rng.present?
                     Array(batch).map do |h, r|
                       { hk => h, rng => r }
                     end
                   else
                     Array(batch).map do |id|
                       { hk => id }
                     end
                   end

            request_items[t] = {
              keys: keys,
              consistent_read: options[:consistent_read]
            }

            results = client.batch_get_item(
              request_items: request_items
            )

            if block_given?
              batch_results = Hash.new([].freeze)

              results.data[:responses].each do |table, rows|
                batch_results[table] += rows.collect { |r| result_item_to_hash(r) }
              end

              yield(batch_results, results.unprocessed_keys.present?)
            else
              results.data[:responses].each do |table, rows|
                ret[table] += rows.collect { |r| result_item_to_hash(r) }
              end
            end

            if results.unprocessed_keys.present?
              ids += results.unprocessed_keys[t].keys.map { |h| h[hk] }
            end
          end
        end

        ret unless block_given?
      end

      # Delete many items at once from DynamoDB. More efficient than delete each item individually.
      #
      # @example Delete IDs 1 and 2 from the table testtable
      #   Dynamoid::AdapterPlugin::AwsSdk.batch_delete_item('table1' => ['1', '2'])
      # or
      #   Dynamoid::AdapterPlugin::AwsSdkV3.batch_delete_item('table1' => [['hk1', 'rk2'], ['hk1', 'rk2']]]))
      #
      # @param [Hash] options the hash of tables and IDs to delete
      #
      # See:
      # * http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
      # * http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#batch_write_item-instance_method
      #
      # TODO handle rejections because of internal processing failures
      def batch_delete_item(options)
        requests = []

        options.each_pair do |table_name, ids|
          table = describe_table(table_name)

          ids.each_slice(BATCH_WRITE_ITEM_REQUESTS_LIMIT) do |sliced_ids|
            delete_requests = sliced_ids.map do |id|
              { delete_request: { key: key_stanza(table, *id) } }
            end

            requests << { table_name => delete_requests }
          end
        end

        begin
          requests.map do |request_items|
            client.batch_write_item(
              request_items: request_items,
              return_consumed_capacity: 'TOTAL',
              return_item_collection_metrics: 'SIZE'
            )
          end
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          raise Dynamoid::Errors::ConditionalCheckFailedException, e
        end
      end

      # Create a table on DynamoDB. This usually takes a long time to complete.
      #
      # @param [String] table_name the name of the table to create
      # @param [Symbol] key the table's primary key (defaults to :id)
      # @param [Hash] options provide a range key here if the table has a composite key
      # @option options [Array<Dynamoid::Indexes::Index>] local_secondary_indexes
      # @option options [Array<Dynamoid::Indexes::Index>] global_secondary_indexes
      # @option options [Symbol] hash_key_type The type of the hash key
      # @option options [Boolean] sync Wait for table status to be ACTIVE?
      # @since 1.0.0
      def create_table(table_name, key = :id, options = {})
        Dynamoid.logger.info "Creating #{table_name} table. This could take a while."
        CreateTable.new(client, table_name, key, options).call
      rescue Aws::DynamoDB::Errors::ResourceInUseException => e
        Dynamoid.logger.error "Table #{table_name} cannot be created as it already exists"
      end

      # Create a table on DynamoDB *synchronously*.
      # This usually takes a long time to complete.
      # CreateTable is normally an asynchronous operation.
      # You can optionally define secondary indexes on the new table,
      #   as part of the CreateTable operation.
      # If you want to create multiple tables with secondary indexes on them,
      #   you must create the tables sequentially.
      # Only one table with secondary indexes can be
      #   in the CREATING state at any given time.
      # See: http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#create_table-instance_method
      #
      # @param [String] table_name the name of the table to create
      # @param [Symbol] key the table's primary key (defaults to :id)
      # @param [Hash] options provide a range key here if the table has a composite key
      # @option options [Array<Dynamoid::Indexes::Index>] local_secondary_indexes
      # @option options [Array<Dynamoid::Indexes::Index>] global_secondary_indexes
      # @option options [Symbol] hash_key_type The type of the hash key
      # @since 1.2.0
      def create_table_synchronously(table_name, key = :id, options = {})
        create_table(table_name, key, options.merge(sync: true))
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
        options ||= {}
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
      # @option options [Boolean] sync Wait for table status check to raise ResourceNotFoundException
      #
      # @since 1.0.0
      def delete_table(table_name, options = {})
        resp = client.delete_table(table_name: table_name)
        UntilPastTableStatus.new(table_name, :deleting).call if options[:sync] &&
                                                                (status = PARSE_TABLE_STATUS.call(resp, :table_description)) &&
                                                                status == TABLE_STATUSES[:deleting]
        table_cache.delete(table_name)
      rescue Aws::DynamoDB::Errors::ResourceInUseException => e
        Dynamoid.logger.error "Table #{table_name} cannot be deleted as it is in use"
        raise e
      end

      def delete_table_synchronously(table_name, options = {})
        delete_table(table_name, options.merge(sync: true))
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
        options = options.dup
        options ||= {}

        table = describe_table(table_name)
        range_key = options.delete(:range_key)
        consistent_read = options.delete(:consistent_read)

        item = client.get_item(table_name: table_name,
                               key: key_stanza(table, key, range_key),
                               consistent_read: consistent_read)[:item]
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
        options = options.dup

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
                                      return_values: 'ALL_NEW')
          result_item_to_hash(result[:attributes])
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          raise Dynamoid::Errors::ConditionalCheckFailedException, e
        end
      end

      # List all tables on DynamoDB.
      #
      # @since 1.0.0
      def list_tables
        [].tap do |result|
          start_table_name = nil
          loop do
            result_page = client.list_tables exclusive_start_table_name: start_table_name
            start_table_name = result_page.last_evaluated_table_name
            result.concat result_page.table_names
            break unless start_table_name
          end
        end
      end

      # Persists an item on DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [Object] object a hash or Dynamoid object to persist
      #
      # @since 1.0.0
      #
      # See: http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#put_item-instance_method
      def put_item(table_name, object, options = {})
        options ||= {}
        item = sanitize_item(object)

        begin
          client.put_item(
            {
              table_name: table_name,
              item: item,
              expected: expected_stanza(options)
            }.merge!(options)
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
      # @param [Hash] options the options to query the table with
      # @option options [String] :hash_value the value of the hash key to find
      # @option options [Number, Number] :range_between find the range key within this range
      # @option options [Number] :range_greater_than find range keys greater than this
      # @option options [Number] :range_less_than find range keys less than this
      # @option options [Number] :range_gte find range keys greater than or equal to this
      # @option options [Number] :range_lte find range keys less than or equal to this
      #
      # @return [Enumerable] matching items
      #
      # @since 1.0.0
      #
      # @todo Provide support for various other options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#query-instance_method
      def query(table_name, options = {})
        Enumerator.new do |yielder|
          table = describe_table(table_name)

          Query.new(client, table, options).call.each do |page|
            yielder.yield(
              page.items.map { |row| result_item_to_hash(row) },
              last_evaluated_key: page.last_evaluated_key
            )
          end
        end
      end

      def query_count(table_name, options = {})
        table = describe_table(table_name)
        options[:select] = 'COUNT'

        Query.new(client, table, options).call
          .map(&:count)
          .reduce(:+)
      end

      # Scan the DynamoDB table. This is usually a very slow operation as it naively filters all data on
      # the DynamoDB servers.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] conditions a hash of attributes: matching records will be returned by the scan
      #
      # @return [Enumerable] matching items
      #
      # @since 1.0.0
      #
      # @todo: Provide support for various options http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#scan-instance_method
      def scan(table_name, conditions = {}, options = {})
        Enumerator.new do |yielder|
          table = describe_table(table_name)

          Scan.new(client, table, conditions, options).call.each do |page|
            yielder.yield(
              page.items.map { |row| result_item_to_hash(row) },
              last_evaluated_key: page.last_evaluated_key
            )
          end
        end
      end

      def scan_count(table_name, conditions = {}, options = {})
        table = describe_table(table_name)
        options[:select] = 'COUNT'

        Scan.new(client, table, conditions, options).call
          .map(&:count)
          .reduce(:+)
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

        scan(table_name, {}, {}).flat_map{ |i| i }.each do |attributes|
          opts = {}
          opts[:range_key] = attributes[rk.to_sym] if rk
          delete_item(table_name, attributes[hk], opts)
        end
      end

      def count(table_name)
        describe_table(table_name, true).item_count
      end

      protected

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
        expected = Hash.new { |h, k| h[k] = {} }
        return expected unless conditions

        conditions.delete(:unless_exists).try(:each) do |col|
          expected[col.to_s][:exists] = false
        end
        conditions.delete(:if_exists).try(:each) do |col, val|
          expected[col.to_s][:exists] = true
          expected[col.to_s][:value] = val
        end
        conditions.delete(:if).try(:each) do |col, val|
          expected[col.to_s][:value] = val
        end

        expected
      end

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
          item.each { |k, v| r[k.to_sym] = v }
        end
      end

      # Build an array of values for Condition
      # Is used in ScanFilter and QueryFilter
      # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Condition.html
      # @params [String] operator: value of RANGE_MAP or FIELD_MAP hash, e.g. "EQ", "LT" etc
      # @params [Object] value: scalar value or array/set
      def attribute_value_list(operator, value)
        self.class.attribute_value_list(operator, value)
      end

      def self.attribute_value_list(operator, value)
        # For BETWEEN and IN operators we should keep value as is (it should be already an array)
        # For all the other operators we wrap the value with array
        if %w[BETWEEN IN].include?(operator)
          [value].flatten
        else
          [value]
        end
      end

      def sanitize_item(attributes)
        attributes.reject do |_, v|
          v.nil? || ((v.is_a?(Set) || v.is_a?(String)) && v.empty?)
        end.transform_values do |v|
          v.is_a?(Hash) ? v.stringify_keys : v
        end
      end
    end
  end
end
