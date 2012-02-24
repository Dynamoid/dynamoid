# encoding: utf-8
module Dynamoid #:nodoc:

  module Adapter
    extend self
    
    def adapter
      reconnect! unless @adapter
      @adapter
    end
    
    def reconnect!
      require "dynamoid/adapter/#{Dynamoid::Config.adapter}" unless Dynamoid::Adapter.const_defined?(Dynamoid::Config.adapter.camelcase)
      @adapter = Dynamoid::Adapter.const_get(Dynamoid::Config.adapter.camelcase)
      @adapter.connect! if @adapter.respond_to?(:connect!)
    end
    
    def method_missing(method, *args)
      return @adapter.send(method, *args) if @adapter.respond_to?(method)
      super
    end
  end
  
end