# encoding: utf-8
require 'aws'

require 'pp'

module Dynamoid
  module Adapter
    module ClientV2; end

    #
    # Uses the low-level V2 client API. 
    #
    class <<ClientV2 #Makes these all static methods on the Module
      attr_reader :table_cache
      # Establish the connection to DynamoDB.
      #
      # @return [AWS::DynamoDB::ClientV2] the raw DynamoDB connection
      
      def connect!
        @client = AWS::DynamoDB::Client.new(:api_version => '2012-08-10')
        @table_cache = {}
      end

      # Return the client object.
      #
      #
      # @since 0.2.0
      def client
        @client
      end

      # Get many items at once from DynamoDB. More efficient than getting each item individually.
      #
      # @example Retrieve IDs 1 and 2 from the table testtable
      #   Dynamoid::Adapter::AwsSdk.batch_get_item({'table1' => ['1', '2']}, :consistent_read => true)
      #
      # @param [Hash] table_ids the hash of tables and IDs to retrieve
      # @param [Hash] options to be passed to underlying BatchGet call
      #
      # @return [Hash] a hash where keys are the table names and the values are the retrieved items
      #
      # @since 0.2.0
      def batch_get_item(table_ids, options = {})
        request_items = {}
        table_ids.each do |t, ids|
          next if ids.empty?
          tbl = describe_table(t)
          hk  = tbl.hash_key.to_s
          rng = tbl.range_key.try :to_s

          keys = if(rng)
            ids.map do |h,r|
              { hk => attribute_value(h), rng => attribute_value(r) }
            end
          else
            ids.map do |id| 
              { hk => attribute_value(id) }
            end
          end

          request_items[t] = {
            keys: keys
          }
        end

        raise "Unhandled options remaining" unless options.empty?
        results = client.batch_get_item(
          request_items: request_items
        )

        results.data
        ret = Hash.new([].freeze) #Default for tables where no rows are returned
        results.data[:responses].each do |table, rows|
          ret[table] = rows.collect { |r| result_item_to_hash(r) }
        end
        ret
      rescue
        STDERR.puts("batch_get_item FAILED")
        PP.pp(request_items)
        raise
      end

      # Delete many items at once from DynamoDB. More efficient than delete each item individually.
      #
      # @example Delete IDs 1 and 2 from the table testtable
      #   Dynamoid::Adapter::AwsSdk.batch_delete_item('table1' => ['1', '2'])
      #or
      #   Dynamoid::Adapter::AwsSdk.batch_delete_item('table1' => [['hk1', 'rk2'], ['hk1', 'rk2']]]))
      #
      # @param [Hash] options the hash of tables and IDs to delete
      #
      # @return nil
      #
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
      # @param [Hash] options provide a range_key here if you want one for the table
      #
      # @since 0.2.0
      def create_table(table_name, key = :id, options = {})
        Dynamoid.logger.info "Creating #{table_name} table. This could take a while."
        read_capacity = options.delete(:read_capacity) || Dynamoid::Config.read_capacity
        write_capacity = options.delete(:write_capacity) || Dynamoid::Config.write_capacity
        range_key = options.delete(:range_key)
        
        key_schema = [
          { attribute_name: key.to_s, key_type: HASH_KEY }
        ]
        key_schema << { 
          attribute_name: range_key.keys.first.to_s, key_type: RANGE_KEY
        } if(range_key)
        
        attribute_definitions = [
          { attribute_name: key.to_s, attribute_type: 'S' }
        ]
        attribute_definitions << {
          attribute_name: range_key.keys.first.to_s, attribute_type: api_type(range_key.values.first)
        } if(range_key)
        
        client.create_table(table_name: table_name, 
          provisioned_throughput: {
            read_capacity_units: read_capacity, 
            write_capacity_units: write_capacity
          },
          key_schema: key_schema,
          attribute_definitions: attribute_definitions
        )
        
        [:id, :table_name].each { |k| options.delete(k) }
        raise "Not empty options: #{options.keys.join(',')}" unless options.empty?

      rescue AWS::DynamoDB::Errors::ResourceInUseException => e
        #STDERR.puts("SWALLOWED AN EXCEPTION creating table #{table_name}")
      rescue
        STDERR.puts("create_table FAILED")
        PP.pp(key_schema)
        raise
      end

      # Removes an item from DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to delete
      # @param [Number] range_key the range key of the item to delete, required if the table has a composite key
      #
      # @since 0.2.0
      def delete_item(table_name, key, options = nil)
        table = describe_table(table_name)
        client.delete_item(table_name: table_name, key: key_stanza(table, key, options && options[:range_key]))

      rescue
        STDERR.puts("delete_item FAILED on #{table_name}, #{key}, #{options}")
        PP.pp(table.schema)
        raise
      end

      # Deletes an entire table from DynamoDB. Only 10 tables can be in the deleting state at once,
      # so if you have more this method may raise an exception.
      #
      # @param [String] table_name the name of the table to destroy
      #
      # @since 0.2.0
      def delete_table(table_name)
        client.delete_table(table_name: table_name)
        table_cache.clear
      end

      # @todo Add a DescribeTable method.

      # Fetches an item from DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to find
      # @param [Number] range_key the range key of the item to find, required if the table has a composite key
      #
      # @return [Hash] a hash representing the raw item in DynamoDB
      #
      # @since 0.2.0
      def get_item(table_name, key, options = {})
        table    = describe_table(table_name)
        range_key = options.delete(:range_key)
        
        result = {}
        
        item = client.get_item(table_name: table_name, 
          key: key_stanza(table, key, range_key)
        )[:item]
        item ? result_item_to_hash(item) : nil
      rescue
        STDERR.puts("get_item FAILED ON #{key}, #{options}")
        STDERR.puts("----")
        PP.pp(item)
        raise
      end

      #
      # @return new attributes for the record
      #
      def update_item(table_name, key, options = {})
          range_key = options.delete(:range_key)
          conditions = options.delete(:conditions)
          table = describe_table(table_name)
          
          yield(iu = ItemUpdater.new(table, key, range_key))
          
          raise "non-empty options: #{options}" unless options.empty?
          
          result = client.update_item(table_name: table_name, 
            key: key_stanza(table, key, range_key),
            attribute_updates: iu.to_h,
            expected: expected_stanza(conditions),
            return_values: "ALL_NEW"
          )
          
          result_item_to_hash(result[:attributes])
        rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException
          raise Dynamoid::Errors::ConditionalCheckFailedException
      end

      # List all tables on DynamoDB.
      #
      # @since 0.2.0
      def list_tables
        client.list_tables[:table_names]
      end

      # Persists an item on DynamoDB.
      #
      # @param [String] table_name the name of the table
      # @param [Object] object a hash or Dynamoid object to persist
      #
      # @since 0.2.0
      def put_item(table_name, object, options = nil)
        item = {}
        
        object.each do |k, v|
          next if v.nil? || (v.respond_to?(:empty?) && v.empty?)
          item[k.to_s] = attribute_value(v)
        end
        
        result = client.put_item(table_name: table_name, 
          item: item,
          expected: expected_stanza(options)
        )
        #STDERR.puts("DATA: #{result.data}")
      rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => e 
        raise Errors::ConditionalCheckFailedException 
      rescue
        STDERR.puts("put_item FAILED ON")
        PP.pp(object)
        STDERR.puts('--- options:')
        PP.pp(options)
        STDERR.puts('---- item:')
        PP.pp(item)
        STDERR.puts('--- expected:')
        PP.pp(expected_stanza(options))
        STDERR.puts("---")
        STDERR.puts(table_name)
        STDERR.puts("---")
        PP.pp describe_table(table_name)
        raise
      end

      # Query the DynamoDB table. This employs DynamoDB's indexes so is generally faster than scanning, but is
      # only really useful for range queries, since it can only find by one hash key at once. Only provide
      # one range key to the hash.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] opts the options to query the table with
      # @option opts [String] :hash_value the value of the hash key to find
      # @option opts [Range] :range_value find the range key within this range
      # @option opts [Number] :range_greater_than find range keys greater than this
      # @option opts [Number] :range_less_than find range keys less than this
      # @option opts [Number] :range_gte find range keys greater than or equal to this
      # @option opts [Number] :range_lte find range keys less than or equal to this
      #
      # @return [Enumerator] an iterator of all matching items
      #
      # @since 0.2.0
      def query(table_name, opts = {})
        table = describe_table(table_name)
        hk    = table.hash_key.to_s
        rng   = table.range_key.to_s
        q     = opts.slice(:consistent_read, :scan_index_forward, :limit)

        opts.delete(:consistent_read)
        opts.delete(:scan_index_forward)
        opts.delete(:limit)
        opts.delete(:next_token).tap do |token|
          break unless token
          q[:exclusive_start_key] = {
            hk  => token[:hash_key_element],
            rng => token[:range_key_element]
          }
        end

        key_conditions = {
          hk => {
            comparison_operator: EQ,
            attribute_value_list: [
              { STRING_TYPE =>  opts.delete(:hash_value).to_s.freeze }
            ]
          }
        }
        opts.each_pair do |k, v|
          next unless(op = RANGE_MAP[k])
          key_conditions[rng] = {
            comparison_operator: op,
            attribute_value_list: [
              { NUM_TYPE => opts.delete(k).to_s.freeze }
            ]
          }
        end

        q[:table_name]     = table_name
        q[:key_conditions] = key_conditions

        raise "MOAR STUFF" unless opts.empty?
        Enumerator.new { |y|
          result = client.query(q)
          result.member.each { |r| 
            y << result_item_to_hash(r)
          }
        }
      end

      EQ = "EQ".freeze
      ID = "id".freeze

      RANGE_MAP = {
        range_greater_than: 'GT',
        range_less_than:    'LT',
        range_gte:          'GE',
        range_lte:          'LE',
        range_begins_with:  'BEGINS_WITH'
      }

      # Scan the DynamoDB table. This is usually a very slow operation as it naively filters all data on
      # the DynamoDB servers.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
      #
      # @return [Enumerator] an iterator of all matching items
      #
      # @since 0.2.0
      def scan(table_name, scan_hash, select_opts)
        limit = select_opts.delete(:limit)
        batch = select_opts.delete(:batch_size)
        
        request = { table_name: table_name }
        request[:limit] = batch || limit if batch || limit
        request[:scan_filter] = scan_hash.reduce({}) do |memo, kvp| 
          memo[kvp[0].to_s] = {
            attribute_value_list: [attribute_value(kvp[1])],
            comparison_operator: EQ
          }
          memo
        end if(scan_hash && !scan_hash.empty?)
                
        raise "non-empty select_opts " if(select_opts && !select_opts.empty?)
        
        Enumerator.new do |y|
          #Batch loop, pulls multiple requests until done using the start_key
          loop do
            results = client.scan(request)
            results.data[:member].each { |row| y << result_item_to_hash(row) }

            if((lk = results[:last_evaluated_key]) && batch)
              #TODO: Properly mix limit and batch
              request[:exclusive_start_key] = lk
            else
              break
            end
          end
        end
      rescue
        STDERR.puts("FAILED scan")
        PP.pp(scan_hash)
        STDERR.puts("---")
        PP.pp(select_opts)
        STDERR.puts("---")
        PP.pp(request)
        raise
      end
      

      #
      # Truncates all records in the given table
      #
      def truncate(table_name)
        table = describe_table(table_name)
        hk    = table.hash_key
        rk    = table.range_key
        
        scan(table_name, {}, {}).each do |attributes|
          opts = {range_key: attributes[rk.to_sym] } if rk
          delete_item(table_name, attributes[hk], opts)
        end
      end
      
      #
      # Legacy method that exposes a DynamoDB v1-list table object
      #
      def get_table(table_name)
        LegacyTable.new(describe_table(table_name))
      end

      def count(table_name)
        describe_table(table_name, true).item_count
      end

      protected
      
      STRING_TYPE = "S".freeze
      STRING_SET  = "SS".freeze
      NUM_TYPE    = "N".freeze

      #
      # Given a value and an options typedef, returns an AttributeValue hash
      # 
      # @param value The value to convert to an AttributeValue hash
      # @param [String] type The target api_type (e.g. "N", "SS") for value. If not supplied, 
      #                 the type will be inferred from the Ruby type
      #
      def attribute_value(value, type = nil)
        if(type)
          value = value.to_s
        else
          case(value)
          when String then
            type = STRING_TYPE
          when Enumerable then 
            type = STRING_SET
            value = value.to_a
          when Numeric then
            type = NUM_TYPE
            value = value.to_s
          else raise "Not sure how to infer type for #{value}"
          end
        end
        { type => value }
      end

      #Converts from symbol to the API string for the given data type
      # E.g. :number -> 'N'
      def api_type(type)
        case(type)
        when :string  then STRING_TYPE
        when :number  then NUM_TYPE
        when :datetime then NUM_TYPE
        else raise "Unknown type: #{type}"
        end
      end
      
      def load_value(value, type)
        case(type)
        when :s  then value
        when :n  then value.to_f
        when :ss then Set.new(value.to_a)
        else raise "Not sure how to load type #{type} for #{value}"
        end
      end
      
      #
      # The key hash passed on get_item, put_item, delete_item, update_item, etc
      #
      def key_stanza(table, hash_key, range_key = nil)
        key = { table.hash_key.to_s => attribute_value(hash_key.to_s, STRING_TYPE) }
        key[table.range_key.to_s] = { table.range_type => range_key.to_s } if range_key
        key
      end
      
      #
      # @param [Hash] conditions Condidtions to enforce on operation (e.g. { :if => { :count => 5 }, :unless_exists => ['id']})
      # @return an Expected stanza for the given conditions hash
      #
      def expected_stanza(conditions = nil)
        expected = Hash.new { |h,k| h[k] = {} }
        return expected unless conditions
        
        conditions[:unless_exists].try(:each) do |col|
          expected[col.to_s][:exists] = false
        end
        conditions[:if].try(:each) do |col,val|
          expected[col.to_s][:value] = attribute_value(val)
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
          item.each { |k,v| r[k.to_sym] = load_value(v.values.first, v.keys.first) }
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
          @range_key ||= schema[:key_schema].find { |d| d[:key_type] == RANGE_KEY }.try(:fetch,:attribute_name)
        end
        
        def range_type
          range_type ||= schema[:attribute_definitions].find { |d| 
            d[:attribute_name] == range_key
          }.try(:fetch,:attribute_type, nil)
        end
        
        def hash_key
          schema[:key_schema].find { |d| d[:key_type] == HASH_KEY  }.try(:fetch,:attribute_name).to_sym
        end
        
        #
        # Returns the API type (e.g. "N", "SS") for the given column, if the schema defines it,
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
      
      class LegacyTable
        def initialize(table)
          @table = table
        end
        
        def range_key
          rk = @table.range_key
          rk && Column.new(@table.range_key)
        end
        
        class Column
          attr_reader :name
          
          def initialize(name)
            @name = name
          end
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
              value: ClientV2.send(:attribute_value, v)
            }
          end
          @deletions.each do |k,v|
            ret[k.to_s] = {
              action: DELETE,
              value: ClientV2.send(:attribute_value, v)
            }
          end
          @updates.each do |k,v|
            ret[k.to_s] = {
              action: PUT,
              value: ClientV2.send(:attribute_value, v)
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
