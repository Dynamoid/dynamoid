# frozen_string_literal: true

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

        if Dynamoid::Config.endpoint?
          @connection_hash[:endpoint] = Dynamoid::Config.endpoint
        end
        if Dynamoid::Config.access_key?
          @connection_hash[:access_key_id] = Dynamoid::Config.access_key
        end
        if Dynamoid::Config.secret_key?
          @connection_hash[:secret_access_key] = Dynamoid::Config.secret_key
        end
        if Dynamoid::Config.region?
          @connection_hash[:region] = Dynamoid::Config.region
        end
        if Dynamoid::Config.http_continue_timeout?
          @connection_hash[:http_continue_timeout] = Dynamoid::Config.http_continue_timeout
        end
        if Dynamoid::Config.http_idle_timeout?
          @connection_hash[:http_idle_timeout] = Dynamoid::Config.http_idle_timeout
        end
        if Dynamoid::Config.http_open_timeout?
          @connection_hash[:http_open_timeout] = Dynamoid::Config.http_open_timeout
        end
        if Dynamoid::Config.http_read_timeout?
          @connection_hash[:http_read_timeout] = Dynamoid::Config.http_read_timeout
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
      def batch_get_item(table_ids, _options = {})
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
              keys: keys
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
        read_capacity = options[:read_capacity] || Dynamoid::Config.read_capacity
        write_capacity = options[:write_capacity] || Dynamoid::Config.write_capacity

        secondary_indexes = options.slice(
          :local_secondary_indexes,
          :global_secondary_indexes
        )
        ls_indexes = options[:local_secondary_indexes]
        gs_indexes = options[:global_secondary_indexes]

        key_schema = {
          hash_key_schema: { key => (options[:hash_key_type] || :string) },
          range_key_schema: options[:range_key]
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
        resp = client.create_table(client_opts)
        options[:sync] = true if !options.key?(:sync) && ls_indexes.present? || gs_indexes.present?
        until_past_table_status(table_name, :creating) if options[:sync] &&
                                                          (status = PARSE_TABLE_STATUS.call(resp, :table_description)) &&
                                                          status == TABLE_STATUSES[:creating]
        # Response to original create_table, which, if options[:sync]
        #   may have an outdated table_description.table_status of "CREATING"
        resp
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
        until_past_table_status(table_name, :deleting) if options[:sync] &&
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
        options ||= {}
        table = describe_table(table_name)
        range_key = options.delete(:range_key)

        item = client.get_item(table_name: table_name,
                               key: key_stanza(table, key, range_key))[:item]
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
        hk    = (opts[:hash_key].present? ? opts.delete(:hash_key) : table.hash_key).to_s
        rng   = (opts[:range_key].present? ? opts.delete(:range_key) : table.range_key).to_s
        q     = opts.slice(
          :consistent_read,
          :scan_index_forward,
          :select,
          :index_name
        )

        opts.delete(:consistent_read)
        opts.delete(:scan_index_forward)
        opts.delete(:select)
        opts.delete(:index_name)

        # Deal with various limits and batching
        record_limit = opts.delete(:record_limit)
        scan_limit = opts.delete(:scan_limit)
        batch_size = opts.delete(:batch_size)
        exclusive_start_key = opts.delete(:exclusive_start_key)
        limit = [record_limit, scan_limit, batch_size].compact.min

        key_conditions = {
          hk => {
            comparison_operator: EQ,
            attribute_value_list: attribute_value_list(EQ, opts.delete(:hash_value).freeze)
          }
        }

        opts.each_pair do |k, _v|
          next unless (op = RANGE_MAP[k])
          key_conditions[rng] = {
            comparison_operator: op,
            attribute_value_list: attribute_value_list(op, opts.delete(k).freeze)
          }
        end

        query_filter = {}
        opts.reject { |k, _| k.in? RANGE_MAP.keys }.each do |attr, hash|
          query_filter[attr] = {
            comparison_operator: FIELD_MAP[hash.keys[0]],
            attribute_value_list: attribute_value_list(FIELD_MAP[hash.keys[0]], hash.values[0].freeze)
          }
        end

        q[:limit] = limit if limit
        q[:exclusive_start_key] = exclusive_start_key if exclusive_start_key
        q[:table_name]     = table_name
        q[:key_conditions] = key_conditions
        q[:query_filter]   = query_filter

        Enumerator.new do |y|
          record_count = 0
          scan_count = 0
          loop do
            # Adjust the limit down if the remaining record and/or scan limit are
            # lower to obey limits. We can assume the difference won't be
            # negative due to break statements below but choose smaller limit
            # which is why we have 2 separate if statements.
            # NOTE: Adjusting based on record_limit can cause many HTTP requests
            # being made. We may want to change this behavior, but it affects
            # filtering on data with potentially large gaps.
            # Example:
            #    User.where('created_at.gte' => 1.day.ago).record_limit(1000)
            #    Records 1-999 User's that fit criteria
            #    Records 1000-2000 Users's that do not fit criteria
            #    Record 2001 fits criteria
            # The underlying implementation will have 1 page for records 1-999
            # then will request with limit 1 for records 1000-2000 (making 1000
            # requests of limit 1) until hit record 2001.
            if q[:limit] && record_limit && record_limit - record_count < q[:limit]
              q[:limit] = record_limit - record_count
            end
            if q[:limit] && scan_limit && scan_limit - scan_count < q[:limit]
              q[:limit] = scan_limit - scan_count
            end

            results = client.query(q)
            results.items.each { |row| y << result_item_to_hash(row) }

            record_count += results.items.size
            break if record_limit && record_count >= record_limit

            scan_count += results.scanned_count
            break if scan_limit && scan_count >= scan_limit

            if (lk = results.last_evaluated_key)
              q[:exclusive_start_key] = lk
            else
              break
            end
          end
        end
      end

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
      def scan(table_name, scan_hash = {}, select_opts = {})
        request = { table_name: table_name }
        request[:consistent_read] = true if select_opts.delete(:consistent_read)

        # Deal with various limits and batching
        record_limit = select_opts.delete(:record_limit)
        scan_limit = select_opts.delete(:scan_limit)
        batch_size = select_opts.delete(:batch_size)
        exclusive_start_key = select_opts.delete(:exclusive_start_key)
        request_limit = [record_limit, scan_limit, batch_size].compact.min
        request[:limit] = request_limit if request_limit
        request[:exclusive_start_key] = exclusive_start_key if exclusive_start_key

        if scan_hash.present?
          request[:scan_filter] = scan_hash.reduce({}) do |memo, (attr, cond)|
            memo.merge(attr.to_s => {
                         comparison_operator: FIELD_MAP[cond.keys[0]],
                         attribute_value_list: attribute_value_list(FIELD_MAP[cond.keys[0]], cond.values[0].freeze)
                       })
          end
        end

        Enumerator.new do |y|
          record_count = 0
          scan_count = 0
          loop do
            # Adjust the limit down if the remaining record and/or scan limit are
            # lower to obey limits. We can assume the difference won't be
            # negative due to break statements below but choose smaller limit
            # which is why we have 2 separate if statements.
            # NOTE: Adjusting based on record_limit can cause many HTTP requests
            # being made. We may want to change this behavior, but it affects
            # filtering on data with potentially large gaps.
            # Example:
            #    User.where('created_at.gte' => 1.day.ago).record_limit(1000)
            #    Records 1-999 User's that fit criteria
            #    Records 1000-2000 Users's that do not fit criteria
            #    Record 2001 fits criteria
            # The underlying implementation will have 1 page for records 1-999
            # then will request with limit 1 for records 1000-2000 (making 1000
            # requests of limit 1) until hit record 2001.
            if request[:limit] && record_limit && record_limit - record_count < request[:limit]
              request[:limit] = record_limit - record_count
            end
            if request[:limit] && scan_limit && scan_limit - scan_count < request[:limit]
              request[:limit] = scan_limit - scan_count
            end

            results = client.scan(request)
            results.items.each { |row| y << result_item_to_hash(row) }

            record_count += results.items.size
            break if record_limit && record_count >= record_limit

            scan_count += results.scanned_count
            break if scan_limit && scan_count >= scan_limit

            # Keep pulling if we haven't finished paging in all data
            if (lk = results[:last_evaluated_key])
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

      def check_table_status?(counter, resp, expect_status)
        status = PARSE_TABLE_STATUS.call(resp)
        again = counter < Dynamoid::Config.sync_retry_max_times &&
                status == TABLE_STATUSES[expect_status]
        { again: again, status: status, counter: counter }
      end

      def until_past_table_status(table_name, status = :creating)
        counter = 0
        resp = nil
        begin
          check = { again: true }
          while check[:again]
            sleep Dynamoid::Config.sync_retry_wait_seconds
            resp = client.describe_table(table_name: table_name)
            check = check_table_status?(counter, resp, status)
            Dynamoid.logger.info "Checked table status for #{table_name} (check #{check.inspect})"
            counter += 1
          end
        # If you issue a DescribeTable request immediately after a CreateTable
        #   request, DynamoDB might return a ResourceNotFoundException.
        # This is because DescribeTable uses an eventually consistent query,
        #   and the metadata for your table might not be available at that moment.
        # Wait for a few seconds, and then try the DescribeTable request again.
        # See: http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#describe_table-instance_method
        rescue Aws::DynamoDB::Errors::ResourceNotFoundException => e
          case status
          when :creating then
            if counter >= Dynamoid::Config.sync_retry_max_times
              Dynamoid.logger.warn "Waiting on table metadata for #{table_name} (check #{counter})"
              retry # start over at first line of begin, does not reset counter
            else
              Dynamoid.logger.error "Exhausted max retries (Dynamoid::Config.sync_retry_max_times) waiting on table metadata for #{table_name} (check #{counter})"
              raise e
            end
          else
            # When deleting a table, "not found" is the goal.
            Dynamoid.logger.info "Checked table status for #{table_name}: Not Found (check #{check.inspect})"
          end
        end
      end

      # Converts from symbol to the API string for the given data type
      # E.g. :number -> 'N'
      def api_type(type)
        case type
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
          index_name: index.name,
          key_schema: key_schema,
          projection: {
            projection_type: index.projection_type.to_s.upcase
          }
        }

        # If the projection type is include, specify the non key attributes
        if index.projection_type == :include
          hash[:projection][:non_key_attributes] = index.projected_attributes
        end

        # Only global secondary indexes have a separate throughput.
        if index.type == :global_secondary
          hash[:provisioned_throughput] = {
            read_capacity_units: index.read_capacity,
            write_capacity_units: index.write_capacity
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
          attribute_name: name.to_s,
          attribute_type: aws_type
        }
      end

      # Build an array of values for Condition
      # Is used in ScanFilter and QueryFilter
      # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Condition.html
      # @params [String] operator: value of RANGE_MAP or FIELD_MAP hash, e.g. "EQ", "LT" etc
      # @params [Object] value: scalar value or array/set
      def attribute_value_list(operator, value)
        # For BETWEEN and IN operators we should keep value as is (it should be already an array)
        # For all the other operators we wrap the value with array
        if %w[BETWEEN IN].include?(operator)
          [value].flatten
        else
          [value]
        end
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
          range_type ||= schema[:attribute_definitions].find do |d|
            d[:attribute_name] == range_key
          end.try(:fetch, :attribute_type, nil)
        end

        def hash_key
          @hash_key ||= schema[:key_schema].find { |d| d[:key_type] == HASH_KEY }.try(:attribute_name).to_sym
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
          @table = table
          @key = key
          @range_key = range_key
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
          @additions.merge!(sanitize_attributes(values))
        end

        #
        # Removes values from the sets of the given columns
        #
        # @param [Hash] values keys of the hash are the columns, values are Arrays/Sets of items
        #               to remove
        #
        def delete(values)
          @deletions.merge!(sanitize_attributes(values))
        end

        #
        # Replaces the values of one or more attributes
        #
        def set(values)
          @updates.merge!(sanitize_attributes(values))
        end

        #
        # Returns an AttributeUpdates hash suitable for passing to the V2 Client API
        #
        def to_h
          ret = {}

          @additions.each do |k, v|
            ret[k.to_s] = {
              action: ADD,
              value: v
            }
          end
          @deletions.each do |k, v|
            ret[k.to_s] = {
              action: DELETE,
              value: v
            }
          end
          @updates.each do |k, v|
            ret[k.to_s] = {
              action: PUT,
              value: v
            }
          end

          ret
        end

        private

        def sanitize_attributes(attributes)
          attributes.transform_values do |v|
            v.is_a?(Hash) ? v.stringify_keys : v
          end
        end

        ADD    = 'ADD'
        DELETE = 'DELETE'
        PUT    = 'PUT'
      end

      def sanitize_item(attributes)
        attributes.reject do |_k, v|
          v.nil? || ((v.is_a?(Set) || v.is_a?(String)) && v.empty?)
        end.transform_values do |v|
          v.is_a?(Hash) ? v.stringify_keys : v
        end
      end
    end
  end
end
