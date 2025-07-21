# frozen_string_literal: true

module Dynamoid
  # Manages multiple configurations for connecting to different DynamoDB instances
  # across multiple AWS accounts or regions.
  #
  # @example Setting up multiple configurations
  #   Dynamoid::MultiConfig.configure do |config|
  #     config.add_config(:primary) do |c|
  #       c.access_key = 'primary_access_key'
  #       c.secret_key = 'primary_secret_key'
  #       c.region = 'us-east-1'
  #       c.namespace = 'primary_app'
  #     end
  #
  #     config.add_config(:secondary) do |c|
  #       c.access_key = 'secondary_access_key'
  #       c.secret_key = 'secondary_secret_key'
  #       c.region = 'us-west-2'
  #       c.namespace = 'secondary_app'
  #     end
  #   end
  #
  # @example Using in models
  #   class User
  #     include Dynamoid::Document
  #
  #     dynamoid_config :primary
  #
  #     field :name, :string
  #   end
  #
  #   class Order
  #     include Dynamoid::Document
  #
  #     dynamoid_config :secondary
  #
  #     field :total, :number
  #   end
  #
  # @since 4.0.0
  module MultiConfig
    extend self

    # Registry to store multiple configurations
    @configurations = {}
    @adapters = {}

    # Configure multiple DynamoDB configurations
    #
    # @yield [Configurator] yields a configurator object to add configurations
    def configure
      yield(Configurator.new) if block_given?
    end

    # Add a new configuration
    #
    # @param [Symbol] name the name of the configuration
    # @param [Hash] options configuration options
    # @yield [Dynamoid::Config] yields config object for configuration
    def add_config(name, options = {})
      config = build_config(options)
      yield(config) if block_given?
      @configurations[name.to_sym] = config
      @adapters[name.to_sym] = nil # Will be lazy loaded
    end

    # Get configuration by name
    #
    # @param [Symbol] name the name of the configuration
    # @return [Dynamoid::Config] the configuration object
    def get_config(name)
      @configurations[name.to_sym] || raise(Dynamoid::Errors::UnknownConfiguration, "Configuration '#{name}' not found")
    end

    # Get adapter for a specific configuration
    #
    # @param [Symbol] name the name of the configuration
    # @return [Dynamoid::Adapter] the adapter instance
    def get_adapter(name)
      config_name = name.to_sym

      unless @configurations.key?(config_name)
        raise Dynamoid::Errors::UnknownConfiguration, "Configuration '#{name}' not found"
      end

      @adapters[config_name] ||= create_adapter_for_config(config_name)
    end

    # List all available configuration names
    #
    # @return [Array<Symbol>] array of configuration names
    def configuration_names
      @configurations.keys
    end

    # Check if a configuration exists
    #
    # @param [Symbol] name the name of the configuration
    # @return [Boolean] true if configuration exists
    def configuration_exists?(name)
      @configurations.key?(name.to_sym)
    end

    # Remove a configuration
    #
    # @param [Symbol] name the name of the configuration to remove
    def remove_config(name)
      config_name = name.to_sym
      @configurations.delete(config_name)
      @adapters.delete(config_name)
    end

    # Clear all configurations
    def clear_all
      @configurations.clear
      @adapters.clear
    end

    private

    # Build a new configuration object with default values
    def build_config(options = {})
      config = create_config_object
      setup_config_defaults(config)
      copy_main_config_values(config)
      apply_custom_options(config, options)
      config
    end

    def create_config_object
      config = Object.new
      config.extend(Dynamoid::Config::Options)
      # Initialize settings and defaults hashes
      config.instance_variable_set(:@settings, {})
      config.instance_variable_set(:@defaults, {})
      config
    end

    def setup_config_defaults(config)
      # Define all the same options as main config
      Dynamoid::Config.defaults.each do |key, default_value|
        next if key == :adapter

        config.option(key, default: default_value)
      end
    end

    def copy_main_config_values(config)
      # Copy current values from main config
      Dynamoid::Config.settings.each do |key, value|
        next if key == :adapter

        config.send("#{key}=", value) if config.respond_to?("#{key}=")
      end
    end

    def apply_custom_options(config, options)
      # Apply custom options
      options.each do |key, value|
        next if key == :adapter

        config.send("#{key}=", value) if config.respond_to?("#{key}=")
      end
    end

    # Create adapter instance for specific configuration
    def create_adapter_for_config(name)
      config = @configurations[name]
      MultiConfigAdapter.new(config)
    end

    # Configurator class for DSL-style configuration
    class Configurator
      def add_config(name, options = {}, &block)
        Dynamoid::MultiConfig.add_config(name, options, &block)
      end
    end
  end

  # Specialized adapter that uses a specific configuration instead of global config
  class MultiConfigAdapter < Adapter
    def initialize(config)
      super()
      @config = config
    end

    # Override adapter method to use specific config
    def adapter
      unless @adapter_.value
        adapter = MultiConfigAwsSdkV3.new(@config)
        adapter.connect!
        @adapter_.compare_and_set(nil, adapter)
        clear_cache!
      end
      @adapter_.value
    end

    def self.adapter_plugin_class
      MultiConfigAwsSdkV3
    end
  end

  # AWS SDK v3 adapter that accepts a specific configuration
  class MultiConfigAwsSdkV3 < AdapterPlugin::AwsSdkV3
    def initialize(config)
      super()
      @config = config
    end

    def connection_config
      @connection_hash = {}
      add_connection_options
      add_credentials
      add_logging_config
      @connection_hash
    end

    def add_connection_options
      connection_config_options = %i[endpoint region http_continue_timeout http_idle_timeout http_open_timeout
                                     http_read_timeout].freeze
      (connection_config_options & @config.settings.compact.keys).each do |option|
        @connection_hash[option] = @config.send(option)
      end
    end

    def add_credentials
      # if credentials are passed, they already contain access key & secret key
      if @config.credentials?
        @connection_hash[:credentials] = @config.credentials
      else
        # otherwise, pass access key & secret key for credentials creation
        @connection_hash[:access_key_id] = @config.access_key if @config.access_key?
        @connection_hash[:secret_access_key] = @config.secret_key if @config.secret_key?
      end
    end

    def add_logging_config
      @connection_hash[:logger] = @config.logger || Dynamoid::Config.logger
      @connection_hash[:log_level] = :debug

      return unless @config.log_formatter || Dynamoid::Config.log_formatter

      @connection_hash[:log_formatter] = @config.log_formatter || Dynamoid::Config.log_formatter
    end
  end
end
