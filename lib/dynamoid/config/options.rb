# Shamelessly stolen from Mongoid!
module Dynamoid #:nodoc
  module Config

    # Encapsulates logic for setting options.
    module Options

      # Get the defaults or initialize a new empty hash.
      #
      # @example Get the defaults.
      #   options.defaults
      #
      # @return [ Hash ] The default options.
      #
      # @since 0.2.0
      def defaults
        @defaults ||= {}
      end

      # Define a configuration option with a default.
      #
      # @example Define the option.
      #   Options.option(:persist_in_safe_mode, :default => false)
      #
      # @param [ Symbol ] name The name of the configuration option.
      # @param [ Hash ] options Extras for the option.
      #
      # @option options [ Object ] :default The default value.
      #
      # @since 0.2.0
      def option(name, options = {})
        defaults[name] = settings[name] = options[:default]

        class_eval <<-RUBY
          def #{name}
            settings[#{name.inspect}]
          end

          def #{name}=(value)
            settings[#{name.inspect}] = value
          end

          def #{name}?
            #{name}
          end
          
          def reset_#{name}
            settings[#{name.inspect}] = defaults[#{name.inspect}]
          end
        RUBY
      end

      # Reset the configuration options to the defaults.
      #
      # @example Reset the configuration options.
      #   config.reset
      #
      # @return [ Hash ] The defaults.
      #
      # @since 0.2.0
      def reset
        settings.replace(defaults)
      end

      # Get the settings or initialize a new empty hash.
      #
      # @example Get the settings.
      #   options.settings
      #
      # @return [ Hash ] The setting options.
      #
      # @since 0.2.0
      def settings
        @settings ||= {}
      end
    end
  end
end
