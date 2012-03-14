require 'aws'

module Dynamoid
  module Adapter
    module AwsSdk
      extend self
      @@connection = nil
    
      def connect!
        @@connection = AWS::DynamoDB.new(:access_key_id => Dynamoid::Config.access_key, :secret_access_key => Dynamoid::Config.secret_key)
      end
    
      def connection
        @@connection
      end
    
      # BatchGetItem
      def batch_get_item(options)
        hash = Hash.new{|h, k| h[k] = []}
        return hash if options.all?{|k, v| v.empty?}
        options.each do |t, ids|
          Array(ids).in_groups_of(100, false) do |group|
            batch = AWS::DynamoDB::BatchGet.new(:config => @@connection.config)
            batch.table(t, :all, Array(group)) unless group.nil? || group.empty?
            batch.each do |table_name, attributes|
              hash[table_name] << attributes.symbolize_keys!
            end
          end
        end
        hash
      end
    
      # CreateTable
      def create_table(table_name, key = :id, options = {})
        options[:hash_key] ||= {key.to_sym => :string}
        options[:range_key] = {options[:range_key].to_sym => :number} if options[:range_key]
        table = @@connection.tables.create(table_name, 100, 20, options)
        sleep 0.5 while table.status == :creating
        return table
      end
    
      # DeleteItem
      def delete_item(table_name, key, range_key = nil)
        table = @@connection.tables[table_name]
        table.load_schema
        result = if table.composite_key?
          table.items.at(key, range_key)
        else
          table.items[key]
        end
        result.delete unless result.attributes.to_h.empty?
        true
      end
    
      # DeleteTable
      def delete_table(table_name)
        @@connection.tables[table_name].delete
      end
    
      # DescribeTable
    
      # GetItem
      def get_item(table_name, key, range_key = nil)
        table = @@connection.tables[table_name]
        table.load_schema
        result = if table.composite_key?
          table.items.at(key, range_key)
        else
          table.items[key]
        end.attributes.to_h
        if result.empty?
          nil
        else
          result.symbolize_keys!
        end
      rescue
        raise [table_name, key, range_key].inspect
      end
    
      # ListTables
      def list_tables
        @@connection.tables.collect(&:name)
      end
    
      # PutItem
      def put_item(table_name, object)
        table = @@connection.tables[table_name]
        table.load_schema
        table.items.create(object.delete_if{|k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?)})
      end
    
      # Query
      def query(table_name, opts = {})
        table = @@connection.tables[table_name]
        table.load_schema
        
        if table.composite_key?
          results = []
          table.items.query(opts).each {|data| results << data.attributes.to_h.symbolize_keys!}
          results
        else
          get_item(table_name, opts[:hash_value])
        end
      end
    
      # Scan
      def scan(table_name, scan_hash)
        table = @@connection.tables[table_name]
        table.load_schema
        results = []
        table.items.where(scan_hash).select do |data|
          results << data.attributes.symbolize_keys!
        end
        results
      end
    
      # UpdateItem
    
      # UpdateTable
    end
  end
end