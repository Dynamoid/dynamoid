# encoding: utf-8
require "uri"
require "dynamoid/config/options"

module Dynamoid #:nodoc
  
  module Config
    extend self
    extend Options
    include ActiveModel::Observing

    option :adapter, :default => 'local'
    option :namespace, :default => defined?(Rails) ? "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" : "dynamoid"
    option :logger, :default => defined?(Rails)
    option :access_key
    option :secret_key
    option :read_capacity, :default => 100
    option :write_capacity, :default => 20
    option :warn_on_scan, :default => true
    option :partitioning, :default => false
    option :partition_size, :default => 200
    option :included_models, :default => []
    
    def default_logger
      defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : ::Logger.new($stdout)
    end

    def logger
      @logger ||= default_logger
    end
    
    def logger=(logger)
      case logger
      when false, nil then @logger = nil
      when true then @logger = default_logger
      else
        @logger = logger if logger.respond_to?(:info)
      end
    end

  end
end
