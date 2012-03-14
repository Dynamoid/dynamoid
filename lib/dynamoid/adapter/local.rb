module Dynamoid
  module Adapter
    module Local
      extend self
      # Gimpy hash that should be somewhat equivalent to what Amazon's actual DynamoDB, for offline development.
    
      def data
        @data ||= {}
      end
    
      def reset_data
        self.data.each {|k, v| v[:data] = {}}
      end
    
      # BatchGetItem
      def batch_get_item(options)
        Hash.new { |h, k| h[k] = Array.new }.tap do |hash|
          options.each do |table_name, keys|
            table = data[table_name]
            if table[:range_key]
              Array(keys).each do |hash_key, range_key|
                hash[table_name] << get_item(table_name, hash_key, range_key)
              end
            else
              Array(keys).each do |key|
                hash[table_name] << get_item(table_name, key)
              end
            end
          end
        end
      end
    
      # CreateTable
      def create_table(table_name, key, options = {})
        data[table_name] = {:hash_key => key, :range_key => options[:range_key], :data => {}}
      end
    
      # DeleteItem
      def delete_item(table_name, key, range_key = nil)
        data[table_name][:data].delete("#{key}.#{range_key}")
      end
    
      # DeleteTable
      def delete_table(table_name)
        data.delete(table_name)
      end
    
      # DescribeTable
    
      # GetItem
      def get_item(table_name, key, range_key = nil)
        if data[table_name][:data]
          data[table_name][:data]["#{key}.#{range_key}"]
        else
          nil
        end
      end
    
      # ListTables
      def list_tables
        data.keys
      end
    
      # PutItem
      def put_item(table_name, object)
        table = data[table_name]
        table[:data][object[table[:hash_key]]]
        table[:data]["#{object[table[:hash_key]]}.#{object[table[:range_key]]}"] = object.delete_if{|k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?)}
      end
    
      # Query
      def query(table_name, opts = {})
        id = opts[:hash_value]
        range_key = data[table_name][:range_key]
        if opts[:range_value]
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
          get_item(table_name, id)
        end
      end
    
      # Scan
      def scan(table_name, scan_hash)
        return [] if data[table_name].nil?
        data[table_name][:data].values.flatten.select{|d| scan_hash.all?{|k, v| !d[k].nil? && d[k] == v}}
      end
    
      # UpdateItem
    
      # UpdateTable
    
    end
  end
end