# frozen_string_literal: true

require 'uri'
require 'logger'
require 'dynamoid/config/options'
require 'dynamoid/config/backoff_strategies/constant_backoff'
require 'dynamoid/config/backoff_strategies/exponential_backoff'

module Dynamoid
  # Contains all the basic configuration information required for Dynamoid: both sensible defaults and required fields.
  # @private
  module Config
    # @since 3.3.1
    DEFAULT_NAMESPACE = if defined?(Rails)
                          klass = Rails.application.class
                          app_name = Rails::VERSION::MAJOR >= 6 ? klass.module_parent_name : klass.parent_name
                          "dynamoid_#{app_name}_#{Rails.env}"
                        else
                          'dynamoid'
                        end

    extend self

    extend Options
    include ActiveModel::Observing if defined?(ActiveModel::Observing)

    # All the default options.
    option :adapter, default: 'aws_sdk_v3'
    option :namespace, default: DEFAULT_NAMESPACE
    option :access_key, default: nil
    option :secret_key, default: nil
    option :credentials, default: nil
    option :region, default: nil
    option :batch_size, default: 100
    option :capacity_mode, default: nil
    option :read_capacity, default: 100
    option :write_capacity, default: 20
    option :warn_on_scan, default: true
    option :error_on_scan, default: false
    option :endpoint, default: nil
    option :identity_map, default: false
    option :timestamps, default: true
    option :sync_retry_max_times, default: 60 # a bit over 2 minutes
    option :sync_retry_wait_seconds, default: 2
    option :convert_big_decimal, default: false
    option :store_attribute_with_nil_value, default: false # keep or ignore attribute with nil value at saving
    option :models_dir, default: './app/models' # perhaps you keep your dynamoid models in a different directory?
    option :application_timezone, default: :utc # available values - :utc, :local, time zone name like "Hawaii"
    option :dynamodb_timezone, default: :utc # available values - :utc, :local, time zone name like "Hawaii"
    option :store_datetime_as_string, default: false # store Time fields in ISO 8601 string format
    option :store_date_as_string, default: false # store Date fields in ISO 8601 string format
    option :store_empty_string_as_nil, default: true # store attribute's empty String value as null
    option :store_boolean_as_native, default: true
    option :store_binary_as_native, default: false
    option :backoff, default: nil # callable object to handle exceeding of table throughput limit
    option :backoff_strategies, default: {
      constant: BackoffStrategies::ConstantBackoff,
      exponential: BackoffStrategies::ExponentialBackoff
    }
    option :log_formatter, default: nil
    option :http_continue_timeout, default: nil # specify if you'd like to overwrite Aws Configure - default: 1
    option :http_idle_timeout, default: nil     #                                                  - default: 5
    option :http_open_timeout, default: nil     #                                                  - default: 15
    option :http_read_timeout, default: nil     #                                                  - default: 60
    option :create_table_on_save, default: true
    option :use_yaml_unsafe_load, default: false
    option :yaml_column_permitted_classes, default: [Symbol, Set, Date, Time, DateTime] # classes to allow when using YAML.safe_load

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
      when false, nil then @logger = ::Logger.new(nil)
      when true then @logger = default_logger
      else
        @logger = logger if logger.respond_to?(:info)
      end
    end

    def build_backoff
      if backoff.is_a?(Hash)
        name = backoff.keys[0]
        args = backoff.values[0]

        backoff_strategies[name].call(args)
      else
        backoff_strategies[backoff].call
      end
    end
  end
end
