# frozen_string_literal: true

require 'concurrent/atom'
require 'dynamoid/adapter_plugin/aws_sdk_v3'

module Dynamoid
  # Adapter's value-add:
  # 1) For the rest of Dynamoid, the gateway to DynamoDB.
  # 2) Allows switching `config.adapter` to ease development of a new adapter.
  # 3) Caches the list of tables Dynamoid knows about.
  # @private
  class Adapter
    def initialize
      @adapter_ = Concurrent::Atom.new(nil)
      @tables_ = Concurrent::Atom.new(nil)
    end

    def tables
      unless @tables_.value
        @tables_.swap { |_value, _args| benchmark('Cache Tables') { list_tables || [] } }
      end
      @tables_.value
    end

    # The actual adapter currently in use.
    #
    # @since 0.2.0
    def adapter
      unless @adapter_.value
        adapter = self.class.adapter_plugin_class.new
        adapter.connect!
        @adapter_.compare_and_set(nil, adapter)
        clear_cache!
      end
      @adapter_.value
    end

    def clear_cache!
      @tables_.swap { |_value, _args| nil }
    end

    # Shows how long it takes a method to run on the adapter. Useful for generating logged output.
    #
    # @param [Symbol|String] method the name of the method to appear in the log
    # @param [Array] args the arguments to the method to appear in the log
    # @yield the actual code to benchmark
    #
    # @return the result of the yield
    #
    # @since 0.2.0
    def benchmark(method, *args)
      start = Time.now
      result = yield
      Dynamoid.logger.debug "(#{((Time.now - start) * 1000.0).round(2)} ms) #{method.to_s.split('_').collect(&:upcase).join(' ')}#{" - #{args.inspect}" unless args.nil? || args.empty?}"
      result
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
    # @param [String, Array] ids to fetch; can also be a string of just one id
    # @param [Hash] options Passed to the underlying query. The :range_key option is required whenever the table has a range key,
    #                       unless multiple ids are passed in.
    #
    # @since 0.2.0
    def read(table, ids, options = {}, &blk)
      if ids.respond_to?(:each)
        batch_get_item({ table => ids }, options, &blk)
      else
        get_item(table, ids, options)
      end
    end

    # Delete an item from a table.
    #
    # @param [String] table the name of the table to write the object to
    # @param [String, Array] ids to delete; can also be a string of just one id
    # @param [Hash] options allowed only +range_key+ - range key or array of
    #                       range keys of the record to delete, can also be
    #                       a string of just one range_key, and +conditions+
    #
    def delete(table, ids, options = {})
      range_key = options[:range_key] # array of range keys that matches the ids passed in
      if ids.respond_to?(:each)
        ids = if range_key.respond_to?(:each)
                # turn ids into array of arrays each element being hash_key, range_key
                ids.each_with_index.map { |id, i| [id, range_key[i]] }
              else
                range_key ? ids.map { |id| [id, range_key] } : ids
              end

        batch_delete_item(table => ids)
      else
        delete_item(table, ids, options)
      end
    end

    # Scans a table. Generally quite slow; try to avoid using scan if at all possible.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Hash] query a hash of attributes: matching records will be returned by the scan
    #
    # @since 0.2.0
    def scan(table, query = {}, opts = {})
      benchmark('Scan', table, query) { adapter.scan(table, query, opts) }
    end

    def create_table(table_name, key, options = {})
      unless tables.include?(table_name)
        result = nil
        benchmark('Create Table') { result = adapter.create_table(table_name, key, options) }
        tables << table_name
        result
      else
        false
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

    %i[batch_get_item delete_item get_item list_tables put_item truncate batch_write_item batch_delete_item execute].each do |m|
      # Method delegation with benchmark to the underlying adapter. Faster than relying on method_missing.
      #
      # @since 0.2.0
      define_method(m) do |*args, &blk|
        benchmark(m, *args) { adapter.send(m, *args, &blk) }
      end
    end

    # Delegate all methods that aren't defind here to the underlying adapter.
    #
    # @since 0.2.0
    def method_missing(method, *args, &block)
      # Don't use keywork arguments delegating (with **kw). It works in
      # different way in different Ruby versions: <= 2.6, 2.7, 3.0 and in some
      # future 3.x versions. Providing that there are no downstream methods
      # with keyword arguments in adapter.
      #
      # https://eregon.me/blog/2019/11/10/the-delegation-challenge-of-ruby27.html

      return benchmark(method, *args) { adapter.send(method, *args, &block) } if adapter.respond_to?(method)

      super
    end

    # Query the DynamoDB table. This employs DynamoDB's indexes so is generally faster than scanning, but is
    # only really useful for range queries, since it can only find by one hash key at once. Only provide
    # one range key to the hash.
    #
    #   Dynamoid.adapter.query('users', { id: [[:eq, '1']], age: [[:between, [10, 30]]] }, { batch_size: 1000 })
    #
    # @param [String] table_name the name of the table
    # @param [Array[Array]] key_conditions conditions for the primary key attributes
    # @param [Array[Array]] non_key_conditions (optional) conditions for non-primary key attributes
    # @param [Hash] options (optional) the options to query the table with
    # @option options [Boolean] :consistent_read You can set the ConsistentRead parameter to true and obtain a strongly consistent result
    # @option options [Boolean] :scan_index_forward Specifies the order for index traversal: If true (default), the traversal is performed in ascending order; if false, the traversal is performed in descending order.
    # @option options [Symbop] :select The attributes to be returned in the result (one of ALL_ATTRIBUTES, ALL_PROJECTED_ATTRIBUTES, ...)
    # @option options [Symbol] :index_name The name of an index to query. This index can be any local secondary index or global secondary index on the table.
    # @option options [Hash] :exclusive_start_key The primary key of the first item that this operation will evaluate.
    # @option options [Integer] :batch_size The number of items to lazily load one by one
    # @option options [Integer] :record_limit The maximum number of items to return (not necessarily the number of evaluated items)
    # @option options [Integer] :scan_limit The maximum number of items to evaluate (not necessarily the number of matching items)
    # @option options [Array[Symbol]] :project The attributes to retrieve from the table
    #
    # @return [Enumerable] matching items
    def query(table_name, key_conditions, non_key_conditions = {}, options = {})
      adapter.query(table_name, key_conditions, non_key_conditions, options)
    end

    def self.adapter_plugin_class
      Dynamoid::AdapterPlugin.const_get(Dynamoid::Config.adapter.camelcase)
    end
  end
end
