# frozen_string_literal: true

# Shamelessly stolen from Mongoid!
module Dynamoid
  module Config
    # Encapsulates logic for setting options.
    # @private
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

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}                                               # def endpoint
            settings[#{name.inspect}]                               #   settings["endpoint"]
          end                                                       # end

          def #{name}=(value)                                       # def endpoint=(value)
            settings[#{name.inspect}] = value                       #   settings["endpoint"] = value
          end                                                       # end

          def #{name}?                                              # def endpoint?
            #{name}                                                 #   endpoint
          end                                                       # end

          def reset_#{name}                                         # def reset_endpoint
            settings[#{name.inspect}] = defaults[#{name.inspect}]   #   settings["endpoint"] = defaults["endpoint"]
          end                                                       # end
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
