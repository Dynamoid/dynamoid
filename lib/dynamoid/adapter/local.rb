module Dynamoid
  module Adapter
    
    # This gimpy hash construct should be equivalent to Amazon's actual DynamoDB, for offline development.
    # All tests pass with either this or connecting to the real DynamoDB, and that's good enough for me.
    module Local
      extend self
      
      # The hash holding all of our data.
      #
      # @return [Hash] a hash of raw values
      #
      # @since 0.2.0
      def data
        @data ||= {}
      end
    
      # A convenience method for testing that destroys all table data without destroying their structure.
      #
      # @since 0.2.0
      def reset_data
        self.data.each {|k, v| v[:data] = {}}
      end
    
      # Get many items at once from the hash.
      # 
      # @example Retrieve IDs 1 and 2 from the table testtable
      #   Dynamoid::Adapter::Local.batch_get_item('table1' => ['1', '2'])
      #
      # @param [Hash] options the hash of tables and IDs to retrieve
      #
      # @return [Hash] a hash where keys are the table names and the values are the retrieved items
      #
      # @since 0.2.0
      def batch_get_item(options)
        Hash.new { |h, k| h[k] = Array.new }.tap do |hash|
          options.each do |table_name, keys|
            table = data[table_name]
            if table[:range_key]
              Array(keys).each do |hash_key, range_key|
                hash[table_name] << get_item(table_name, hash_key, :range_key => range_key)
              end
            else
              Array(keys).each do |key|
                hash[table_name] << get_item(table_name, key)
              end
            end
          end
        end
      end
    
      # Create a table.
      #
      # @param [String] table_name the name of the table to create
      # @param [Symbol] key the table's primary key (defaults to :id)
      # @param [Hash] options provide a range_key here if you want one for the table
      #
      # @since 0.2.0
      def create_table(table_name, key, options = {})
        range_key = options[:range_key] && options[:range_key].keys.first
        data[table_name] = {:hash_key => key, :range_key => range_key, :data => {}}
      end
    
      # Removes an item from the hash.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to delete
      # @param [Number] range_key the range key of the item to delete, required if the table has a composite key
      #
      # @since 0.2.0
      def delete_item(table_name, key, options = {})
        range_key = options.delete(:range_key)
        data[table_name][:data].delete("#{key}.#{range_key}")
      end
    
      # Deletes an entire table from the hash.
      #
      # @param [String] table_name the name of the table to destroy
      #
      # @since 0.2.0
      def delete_table(table_name)
        data.delete(table_name)
      end
    
      # @todo Add a DescribeTable method.
    
      # Fetches an item from the hash.
      #
      # @param [String] table_name the name of the table
      # @param [String] key the hash key of the item to find
      # @param [Number] range_key the range key of the item to find, required if the table has a composite key
      #
      # @return [Hash] a hash representing the raw item
      #
      # @since 0.2.0
      def get_item(table_name, key, options = {})
        range_key = options[:range_key]
        if data[table_name][:data]
          data[table_name][:data]["#{key}.#{range_key}"]
        else
          nil
        end
      end
    
      # List all tables on DynamoDB.
      #
      # @since 0.2.0
      def list_tables
        data.keys
      end
    
      # Persists an item in the hash.
      #
      # @param [String] table_name the name of the table
      # @param [Object] object a hash or Dynamoid object to persist
      #
      # @since 0.2.0
      def put_item(table_name, object)
        table = data[table_name]
        table[:data][object[table[:hash_key]]]
        table[:data]["#{object[table[:hash_key]]}.#{object[table[:range_key]]}"] = object.delete_if{|k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?)}
      end
    
      # Query the hash.
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
      # @return [Array] an array of all matching items
      #
      # @since 0.2.0
      def query(table_name, opts = {})
        id = opts[:hash_value]
        range_key = data[table_name][:range_key]

        results = if opts[:range_value]
          data[table_name][:data].values.find_all{|v| v[:id] == id && !v[range_key].nil? && opts[:range_value].include?(v[range_key])}
        elsif opts[:range_greater_than]
          data[table_name][:data].values.find_all{|v| v[:id] == id && !v[range_key].nil? && v[range_key] > opts[:range_greater_than]}
        elsif opts[:range_less_than]
          data[table_name][:data].values.find_all{|v| v[:id] == id && !v[range_key].nil? && v[range_key] < opts[:range_less_than]}
        elsif opts[:range_gte]
          data[table_name][:data].values.find_all{|v| v[:id] == id && !v[range_key].nil? && v[range_key] >= opts[:range_gte]}
        elsif opts[:range_lte]  
          data[table_name][:data].values.find_all{|v| v[:id] == id && !v[range_key].nil? && v[range_key] <= opts[:range_lte]}
        else
          data[table_name][:data].values.find_all{|v| v[:id] == id}
        end

        results = drop_till_start(results, opts[:next_token], range_key)
        results = results.take(opts[:limit]) if opts[:limit]
        results
      end
    
      # Scan the hash.
      #
      # @param [String] table_name the name of the table
      # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
      #
      # @return [Array] an array of all matching items
      #
      # @since 0.2.0
      def scan(table_name, scan_hash, opts = {})
        return [] if data[table_name].nil?
        results = data[table_name][:data].values.flatten.select{|d| scan_hash.all?{|k, v| !d[k].nil? && d[k] == v}}
        results = drop_till_start(results, opts[:next_token], data[table_name][:range_key])
        results = results.take(opts[:limit]) if opts[:limit]
        results
      end

      def drop_till_start(results, next_token, range_key)
        return results unless next_token

        hash_value = next_token[:hash_key_element].values.first
        range_value = next_token[:range_key_element].values.first if next_token[:range_key_element]

        results = results.drop_while do |r|
          (r[:id] != hash_value or r[range_key] != range_value)
        end.drop(1)
      end
    
      # @todo Add an UpdateItem method.
    
      # @todo Add an UpdateTable method.
    end
  end
end
