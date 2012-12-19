# encoding: utf-8
module Dynamoid

  # Adapter provides a generic, write-through class that abstracts variations in the underlying connections to provide a uniform response
  # to Dynamoid.
  module Adapter
    extend self
    attr_accessor :tables

    # The actual adapter currently in use: presently AwsSdk.
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
    # @param [Hash] options Options that are passed to the put_item call
    #
    # @return [Object] the persisted object
    #
    # @since 0.2.0
    def write(table, object, options = nil)
      if Dynamoid::Config.partitioning? && object[:id]
        object[:id] = "#{object[:id]}.#{Random.rand(Dynamoid::Config.partition_size)}"
        object[:updated_at] = Time.now.to_f
      end
      put_item(table, object, options)
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
    def read(table, ids, options = {})
      range_key = options[:range_key]
      if ids.respond_to?(:each)
        ids = ids.collect{|id| range_key ? [id, range_key] : id}
        if Dynamoid::Config.partitioning?
          results = batch_get_item(table => id_with_partitions(ids))
          {table => result_for_partition(results[table],table)}
        else
          batch_get_item(table => ids)
        end
      else
        if Dynamoid::Config.partitioning?
          ids = range_key ? [[ids, range_key]] : ids
          results = batch_get_item(table => id_with_partitions(ids))
          result_for_partition(results[table],table).first
        else
          get_item(table, ids, options)
        end
      end
    end

    # Delete an item from a table. If partitioning is turned on, deletes all partitioned keys as well.
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
        
        if Dynamoid::Config.partitioning?
          batch_delete_item(table => id_with_partitions(ids))
        else
          batch_delete_item(table => ids)
        end
      else
        if Dynamoid::Config.partitioning?
          ids = range_key ? [[ids, range_key]] : ids
          batch_delete_item(table => id_with_partitions(ids))
        else
          delete_item(table, ids, options)
        end
      end
    end

    # Scans a table. Generally quite slow; try to avoid using scan if at all possible.
    #
    # @param [String] table the name of the table to write the object to
    # @param [Hash] scan_hash a hash of attributes: matching records will be returned by the scan
    #
    # @since 0.2.0
    def scan(table, query, opts = {})
      if Dynamoid::Config.partitioning?
        results = benchmark('Scan', table, query) {adapter.scan(table, query, opts)}
        result_for_partition(results,table)
      else
        benchmark('Scan', table, query) {adapter.scan(table, query, opts)}
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
    
    #Get original id (hash_key) and partiton number from a hash_key
    #
    # @param [String] id the id or hash_key of a record, ex. xxxxx.13
    #
    # @return [String,String] original_id and the partition number, ex original_id = xxxxx partition = 13
    def get_original_id_and_partition id
      partition = id.split('.').last
      id = id.split(".#{partition}").first

      return id, partition
    end

    # Takes an array of query results that are partitioned, find the most recently updated ones that share an id and range_key, and return only the most recently updated. Compares each result by
    # their id and updated_at attributes; if the updated_at is the greatest, then it must be the correct result.
    #
    # @param [Array] returned partitioned results from a query
    # @param [String] table_name the name of the table
    #
    # @since 0.2.0
    def result_for_partition(results, table_name)
      table = Dynamoid::Adapter::AwsSdk.get_table(table_name)
      
      if table.range_key     
        range_key_name = table.range_key.name.to_sym
        
        final_hash = {}
        
        results.each do |record|
          test_record = final_hash[record[range_key_name]]
          
          if test_record.nil? || ((record[range_key_name] == test_record[range_key_name]) && (record[:updated_at] > test_record[:updated_at]))
            #get ride of our partition and put it in the array with the range key
            record[:id], partition = get_original_id_and_partition  record[:id]
            final_hash[record[range_key_name]] = record
          end
        end
  
        return final_hash.values
      else
        {}.tap do |hash|
          Array(results).each do |result|
            next if result.nil?
            #Need to find the value of id with out the . and partition number
            id, partition = get_original_id_and_partition result[:id]
  
            if !hash[id] || (result[:updated_at] > hash[id][:updated_at])
              result[:id] = id
              hash[id] = result
            end
          end
        end.values
      end
    end

    # Delegate all methods that aren't defind here to the underlying adapter.
    #
    # @since 0.2.0
    def method_missing(method, *args, &block)
      return benchmark(method, *args) {adapter.send(method, *args, &block)} if @adapter.respond_to?(method)
      super
    end
    
    # Query the DynamoDB table. This employs DynamoDB's indexes so is generally faster than scanning, but is
    # only really useful for range queries, since it can only find by one hash key at once. Only provide
    # one range key to the hash. If paritioning is on, will run a query for every parition and join the results
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
      
      unless Dynamoid::Config.partitioning?
        #no paritioning? just pass to the standard query method
        Dynamoid::Adapter::AwsSdk.query(table_name, opts)
      else
        #get all the hash_values that could be possible
        ids = id_with_partitions(opts[:hash_value])

        #lets not overwrite with the original options
        modified_options = opts.clone     
        results = []
        
        #loop and query on each of the partition ids
        ids.each do |id|
          modified_options[:hash_value] = id

          query_result = Dynamoid::Adapter::AwsSdk.query(table_name, modified_options)
          query_result = [query_result] if !query_result.is_a?(Array)

          results = results + query_result unless query_result.nil? 
        end 
        
        result_for_partition results, table_name
      end
    end
  end
end
