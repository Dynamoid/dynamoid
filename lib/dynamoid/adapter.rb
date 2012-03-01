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
      self.tables = benchmark('Cache Tables') {@adapter.list_tables}
    end
    
    def benchmark(method, *args)
      start = Time.now
      result = yield
      Dynamoid.logger.info "(#{((Time.now - start) * 1000.0).round(2)} ms) #{method.to_s.split('_').collect(&:upcase).join(' ')}#{ " - #{args.join(',')}" unless args.empty? }"
      return result
    end
    
    def method_missing(method, *args)
      return benchmark(method, *args) {@adapter.send(method, *args)} if @adapter.respond_to?(method)
      super
    end
  end
  
end