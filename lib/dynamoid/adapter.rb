# require only 'concurrent/atom' once this issue is resolved:
#   https://github.com/ruby-concurrency/concurrent-ruby/pull/377
require 'concurrent'

# encoding: utf-8
module Dynamoid

  # Adapter's value-add:
  # 1) For the rest of Dynamoid, the gateway to DynamoDB.
  # 2) Allows switching `config.adapter` to ease development of a new adapter.
  # 3) Caches the list of tables Dynamoid knows about.
  class Adapter
    def initialize
      @adapter_ = Concurrent::Atom.new(nil)
      @tables_ = Concurrent::Atom.new(nil)
    end

    def tables
      if !@tables_.value
        @tables_.swap{|value, args| benchmark('Cache Tables') { list_tables } }
      end
      @tables_.value
    end

    # The actual adapter currently in use.
    #
    # @since 0.2.0
    def adapter
      if !@adapter_.value
        adapter = self.class.adapter_plugin_class.new
        adapter.connect! if adapter.respond_to?(:connect!)
        @adapter_.compare_and_set(nil, adapter)
        clear_cache!
      end
      @adapter_.value
    end

    def clear_cache!
      @tables_.swap{|value, args| nil}
    end

    # Shows how long it takes a method to run on the adapter. Useful for generating logged output.
    #
    # @param [Symbol] method the name of the method to appear in the log
    # @param [Array] args the arguments to the method to appear in the log
    # @yield the actual code to benchmark
    #
    # @return the result of the yield
    #
    # @since 0.2.0
    def benchmark(method, *args)
      start = Time.now
      result = yield
      Dynamoid.logger.info "(#{((Time.now - start) * 1000.0).round(2)} ms) #{method.to_s.split('_').collect(&:upcase).join(' ')}#{ " - #{args.inspect}" unless args.nil? || args.empty? }"
      return result
    end

    # Write an object to the adapter.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Object] object the object itself
    # @param [Hash] options Options that are passed to the put_item call
    #
    # @return [Object] the persisted object
    #
    # @since 0.2.0
    def write(table, object, options = nil)
      put_item(table, object, options)
    end

    # Read one or many keys from the selected table.
    # This method intelligently calls batch_get or get on the underlying adapter
    # depending on whether ids is a range or a single key.
    # If a range key is present, it will also interpolate that into the ids so
    # that the batch get will acquire the correct record.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Array] ids to fetch, can also be a string of just one id
    # @param [Hash] options: Passed to the underlying query. The :range_key option is required whenever the table has a range key,
    #                        unless multiple ids are passed in.
    #
    # @since 0.2.0
    def read(table, ids, options = {})
      range_key = options.delete(:range_key)

      if ids.respond_to?(:each)
        ids = ids.collect{|id| range_key ? [id, range_key] : id}
        batch_get_item({table => ids}, options)
      else
        options[:range_key] = range_key if range_key
        get_item(table, ids, options)
      end
    end

    # Delete an item from a table.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Array] ids to delete, can also be a string of just one id
    # @param [Array] range_key of the record to delete, can also be a string of just one range_key
    #
    def delete(table, ids, options = {})
      range_key = options[:range_key] #array of range keys that matches the ids passed in
      if ids.respond_to?(:each)
        if range_key.respond_to?(:each)
          #turn ids into array of arrays each element being hash_key, range_key
          ids = ids.each_with_index.map{|id,i| [id,range_key[i]]}
        else
          ids = range_key ? [[ids, range_key]] : ids
        end

        batch_delete_item(table => ids)
      else
        delete_item(table, ids, options)
      end
    end

    # Scans a table. Generally quite slow; try to avoid using scan if at all possible.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
    #
    # @since 0.2.0
    def scan(table, query, opts = {})
      benchmark('Scan', table, query) {adapter.scan(table, query, opts)}
    end

    def create_table(table_name, key, options = {})
      if !tables.include?(table_name)
        benchmark('Create Table') { adapter.create_table(table_name, key, options) }
        tables << table_name
      end
    end

    # @since 0.2.0
    def delete_table(table_name, options = {})
      if tables.include?(table_name)
        benchmark('Delete Table') { adapter.delete_table(table_name, options) }
        idx = tables.index(table_name)
        tables.delete_at(idx)
      end
    end

    [:batch_get_item, :delete_item, :get_item, :list_tables, :put_item, :truncate, :batch_write_item, :batch_delete_item].each do |m|
      # Method delegation with benchmark to the underlying adapter. Faster than relying on method_missing.
      #
      # @since 0.2.0
      define_method(m) do |*args|
        benchmark("#{m.to_s}", args) {adapter.send(m, *args)}
      end
    end

    # Delegate all methods that aren't defind here to the underlying adapter.
    #
    # @since 0.2.0
    def method_missing(method, *args, &block)
      return benchmark(method, *args) {adapter.send(method, *args, &block)} if adapter.respond_to?(method)
      super
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
    # @return [Array] an array of all matching items
    #
    def query(table_name, opts = {})
      adapter.query(table_name, opts)
    end

    private

    def self.adapter_plugin_class
      unless Dynamoid.const_defined?(:AdapterPlugin) && Dynamoid::AdapterPlugin.const_defined?(Dynamoid::Config.adapter.camelcase)
        require "dynamoid/adapter_plugin/#{Dynamoid::Config.adapter}"
      end

      Dynamoid::AdapterPlugin.const_get(Dynamoid::Config.adapter.camelcase)
    end

  end
end
