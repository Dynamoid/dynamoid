# encoding: utf-8
module Dynamoid #:nodoc:

  module Adapter
    extend self
    attr_accessor :tables
    
    def adapter
      reconnect! unless @adapter
      @adapter
    end
    
    def reconnect!
      require "dynamoid/adapter/#{Dynamoid::Config.adapter}" unless Dynamoid::Adapter.const_defined?(Dynamoid::Config.adapter.camelcase)
      @adapter = Dynamoid::Adapter.const_get(Dynamoid::Config.adapter.camelcase)
      @adapter.connect! if @adapter.respond_to?(:connect!)
      self.tables = benchmark('Cache Tables') {list_tables}
    end
    
    def benchmark(method, *args)
      start = Time.now
      result = yield
      Dynamoid.logger.info "(#{((Time.now - start) * 1000.0).round(2)} ms) #{method.to_s.split('_').collect(&:upcase).join(' ')}#{ " - #{args.inspect}" unless args.nil? || args.empty? }"
      return result
    end
    
    def write(table, object)
      if Dynamoid::Config.partitioning? && object[:id]
        object[:id] = "#{object[:id]}.#{Random.rand(Dynamoid::Config.partition_size)}"
        object[:updated_at] = Time.now.to_f
      end
      benchmark('Put Item', object) {put_item(table, object)}
    end
    
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
    
    def delete(table, id)
      if Dynamoid::Config.partitioning?
        benchmark('Delete Item', id) do
          id_with_partitions(id).each {|i| delete_item(table, i)}
        end
      else
        benchmark('Delete Item', id) {delete_item(table, id)}
      end
    end
    
    def scan(table, query)
      if Dynamoid::Config.partitioning?
        results = benchmark('Scan', table, query) {adapter.scan(table, query)}
        result_for_partition(results)
      else
        adapter.scan(table, query)
      end
    end
    
    [:batch_get_item, :create_table, :delete_item, :delete_table, :get_item, :list_tables, :put_item].each do |m|
      define_method(m) do |*args|
        benchmark("#{m.to_s}", args) {adapter.send(m, *args)}
      end
    end
    
    def id_with_partitions(ids)
      Array(ids).collect {|id| (0...Dynamoid::Config.partition_size).collect{|n| id.is_a?(Array) ? ["#{id.first}.#{n}", id.last] : "#{id}.#{n}"}}.flatten(1)
    end
    
    def result_for_partition(results)
      Hash.new.tap do |hash|
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
    
    def method_missing(method, *args)
      return benchmark(method, *args) {adapter.send(method, *args)} if @adapter.respond_to?(method)
      super
    end
    
  end
  
end
