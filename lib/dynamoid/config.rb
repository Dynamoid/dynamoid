# encoding: utf-8
require "uri"
require "dynamoid/config/options"

module Dynamoid

  # Contains all the basic configuration information required for Dynamoid: both sensible defaults and required fields.
  module Config
    extend self
    extend Options
    include ActiveModel::Observing if defined?(ActiveModel::Observing)

    # All the default options.
    option :adapter, :default => 'aws_sdk_v2'
    option :namespace, :default => defined?(Rails) ? "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" : "dynamoid"
    option :logger, :default => defined?(Rails)
    option :access_key
    option :secret_key
    option :batch_size, :default => 100
    option :read_capacity, :default => 100
    option :write_capacity, :default => 20
    option :warn_on_scan, :default => true
    option :endpoint, :default => nil
    option :use_ssl, :default => true
    option :port, :default => '443'
    option :identity_map, :default => false
    option :timestamps, :default => true
    option :sync_retry_max_times, :default => 60 # a bit over 2 minutes
    option :sync_retry_wait_seconds, :default => 2
    option :convert_big_decimal, :default => false

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
