# encoding: utf-8
module Dynamoid

  # Adapter provides a generic, write-through class that abstracts variations in the underlying connections to provide a uniform response 
  # to Dynamoid.
  module Adapter
    extend self
    attr_accessor :tables
    
    # The actual adapter currently in use: presently, either AwsSdk or Local.
    #
    # @since 0.2.0
    def adapter
      reconnect! unless @adapter
      @adapter
    end
    
    # Establishes a connection to the underyling adapter and caches all its tables for speedier future lookups. Issued when the adapter is first called.
    #
    # @since 0.2.0
    def reconnect!
      require "dynamoid/adapter/#{Dynamoid::Config.adapter}" unless Dynamoid::Adapter.const_defined?(Dynamoid::Config.adapter.camelcase)
      @adapter = Dynamoid::Adapter.const_get(Dynamoid::Config.adapter.camelcase)
      @adapter.connect! if @adapter.respond_to?(:connect!)
      self.tables = benchmark('Cache Tables') {list_tables}
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
    
    # Write an object to the adapter. Partition it to a randomly selected key first if necessary.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Object] object the object itself
    #
    # @return [Object] the persisted object
    #
    # @since 0.2.0
    def write(table, object)
      if Dynamoid::Config.partitioning? && object[:id]
        object[:id] = "#{object[:id]}.#{Random.rand(Dynamoid::Config.partition_size)}"
        object[:updated_at] = Time.now.to_f
      end
      benchmark('Put Item', object) {put_item(table, object)}
    end
    
    # Read one or many keys from the selected table. This method intelligently calls batch_get or get on the underlying adapter depending on
    # whether ids is a range or a single key: additionally, if partitioning is enabled, it batch_gets all keys in the partition space
    # automatically. Finally, if a range key is present, it will also interpolate that into the ids so that the batch get will acquire the 
    # correct record.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Array] ids to fetch, can also be a string of just one id
    # @param [Number] range_key the range key of the record
    #
    # @since 0.2.0
    def read(table, ids, range_key = nil)
      if ids.respond_to?(:each)
        ids = ids.collect{|id| range_key ? [id, range_key] : id}
        if Dynamoid::Config.partitioning?
          results = benchmark('Partitioned Batch Get Item', ids) {batch_get_item(table => id_with_partitions(ids))}
          {table => result_for_partition(results[table])}
        else
          benchmark('Batch Get Item', ids) {batch_get_item(table => ids)}
        end
      else
        if Dynamoid::Config.partitioning?
          ids = range_key ? [[ids, range_key]] : ids
          results = benchmark('Partitioned Get Item', ids) {batch_get_item(table => id_with_partitions(ids))}
          result_for_partition(results[table]).first
        else
          benchmark('Get Item', ids) {get_item(table, ids, range_key)}
        end
      end
    end
    
    # Delete an item from a table. If partitioning is turned on, deletes all partitioned keys as well.
    #
    # @param [String] table the name of the table to write the object to
    # @param [String] id the id of the record
    # @param [Number] range_key the range key of the record
    #
    # @since 0.2.0
    def delete(table, id, range_key = nil)
      if Dynamoid::Config.partitioning?
        benchmark('Delete Item', id) do
          id_with_partitions(id).each {|i| delete_item(table, i, range_key)}
        end
      else
        benchmark('Delete Item', id) {delete_item(table, id, range_key)}
      end
    end
    
    # Scans a table. Generally quite slow; try to avoid using scan if at all possible.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
    #
    # @since 0.2.0    
    def scan(table, query)
      if Dynamoid::Config.partitioning?
        results = benchmark('Scan', table, query) {adapter.scan(table, query)}
        result_for_partition(results)
      else
        adapter.scan(table, query)
      end
    end
    
    [:batch_get_item, :create_table, :delete_item, :delete_table, :get_item, :list_tables, :put_item].each do |m|
      # Method delegation with benchmark to the underlying adapter. Faster than relying on method_missing.
      #
      # @since 0.2.0
      define_method(m) do |*args|
        benchmark("#{m.to_s}", args) {adapter.send(m, *args)}
      end
    end
    
    # Takes a list of ids and returns them with partitioning added. If an array of arrays is passed, we assume the second key is the range key 
    # and pass it in unchanged.
    #
    # @example Partition id 1
    #   Dynamoid::Adapter.id_with_partitions(['1']) # ['1.0', '1.1', '1.2', ..., '1.199']
    # @example Partition id 1 and range_key 1.0
    #   Dynamoid::Adapter.id_with_partitions([['1', 1.0]]) # [['1.0', 1.0], ['1.1', 1.0], ['1.2', 1.0], ..., ['1.199', 1.0]]
    #
    # @param [Array] ids array of ids to partition
    #
    # @since 0.2.0 
    def id_with_partitions(ids)
      Array(ids).collect {|id| (0...Dynamoid::Config.partition_size).collect{|n| id.is_a?(Array) ? ["#{id.first}.#{n}", id.last] : "#{id}.#{n}"}}.flatten(1)
    end
    
    # Takes an array of results that are partitioned, find the most recently updated one, and return only it. Compares each result by 
    # their id and updated_at attributes; if the updated_at is the greatest, then it must be the correct result.
    #
    # @param [Array] returned partitioned results from a query 
    #
    # @since 0.2.0
    def result_for_partition(results)
      {}.tap do |hash|
        Array(results).each do |result|
          next if result.nil?
          id = result[:id].split('.').first
          if !hash[id] || (result[:updated_at] > hash[id][:updated_at])
            result[:id] = id
            hash[id] = result
          end
        end
      end.values
    end
    
    # Delegate all methods that aren't defind here to the underlying adapter.
    #
    # @since 0.2.0
    def method_missing(method, *args)
      return benchmark(method, *args) {adapter.send(method, *args)} if @adapter.respond_to?(method)
      super
    end
    
  end
  
end
