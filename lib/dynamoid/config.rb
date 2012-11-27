# encoding: utf-8
require "uri"
require "dynamoid/config/options"

module Dynamoid

  # Contains all the basic configuration information required for Dynamoid: both sensible defaults and required fields.
  module Config
    extend self
    extend Options
    include ActiveModel::Observing

    # All the default options.
    option :adapter, :default => 'aws-sdk'
    option :namespace, :default => defined?(Rails) ? "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" : "dynamoid"
    option :logger, :default => defined?(Rails)
    option :access_key
    option :secret_key
    option :read_capacity, :default => 100
    option :write_capacity, :default => 20
    option :warn_on_scan, :default => true
    option :partitioning, :default => false
    option :partition_size, :default => 200
    option :endpoint, :default => 'dynamodb.us-east-1.amazonaws.com'
    option :use_ssl, :default => true
    option :port, :default => '443'
    option :included_models, :default => []
    option :identity_map, :default => false

    # The default logger for Dynamoid: either the Rails logger or just stdout.
    #
    # @since 0.2.0
    def default_logger
      defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : ::Logger.new($stdout)
    end

    # Returns the assigned logger instance.
    #
    # @since 0.2.0
    def logger
      @logger ||= default_logger
    end

    # If you want to, set the logger manually to any output you'd like. Or pass false or nil to disable logging entirely.
    #
    # @since 0.2.0
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
