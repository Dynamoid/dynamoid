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
            Array(keys).each do |key|
              hash[table_name] << table[:data][key]
            end
          end
        end
      end
    
      # CreateTable
      def create_table(table_name, key)
        data[table_name] = {:id => key, :data => {}}
      end
    
      # DeleteItem
      def delete_item(table_name, key)
        data[table_name][:data].delete(key)
      end
    
      # DeleteTable
      def delete_table(table_name)
        data.delete(table_name)
      end
    
      # DescribeTable
    
      # GetItem
      def get_item(table_name, key)
        data[table_name][:data][key]
      end
    
      # ListTables
      def list_tables
        data.keys
      end
    
      # PutItem
      def put_item(table_name, object)
        table = data[table_name]
        table[:data][object[table[:id]]] = object.delete_if{|k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?)}
      end
    
      # Query
      def query(table_name, id)
        get_item(table_name, id)
      end
    
      # Scan
      def scan(table_name, scan_hash)
        return [] if data[table_name].nil?
        data[table_name][:data].values.select{|d| scan_hash.all?{|k, v| !d[k].nil? && d[k] == v}}
      end
    
      # UpdateItem
    
      # UpdateTable
    
    end
  end
end