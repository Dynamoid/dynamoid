# frozen_string_literal: true

module Dynamoid
  # @private
  module Undumping
    def self.undump_attributes(attributes, attributes_options)
      {}.tap do |h|
        # ignore existing attributes not declared in document class
        attributes.symbolize_keys
          .select { |attribute| attributes_options.key?(attribute) }
          .each do |attribute, value|
          h[attribute] = undump_field(value, attributes_options[attribute])
        end
      end
    end

    def self.undump_field(value, options)
      return nil if value.nil?

      undumper = find_undumper(options)

      if undumper.nil?
        raise ArgumentError, "Unknown type #{options[:type]}"
      end

      undumper.process(value)
    end

    def self.find_undumper(options)
      undumper_class = case options[:type]
                       when :string     then StringUndumper
                       when :integer    then IntegerUndumper
                       when :number     then NumberUndumper
                       when :set        then SetUndumper
                       when :array      then ArrayUndumper
                       when :map        then MapUndumper
                       when :datetime   then DateTimeUndumper
                       when :date       then DateUndumper
                       when :raw        then RawUndumper
                       when :serialized then SerializedUndumper
                       when :boolean    then BooleanUndumper
                       when :binary     then BinaryUndumper
                       when Class       then CustomTypeUndumper
                       end

      if undumper_class.present?
        undumper_class.new(options)
      end
    end

    module UndumpHashHelper
      extend self

      def undump_hash(hash)
        {}.tap do |h|
          hash.each { |key, value| h[key.to_sym] = undump_hash_value(value) }
        end
      end

      private

      def undump_hash_value(val)
        case val
        when BigDecimal
          if Dynamoid::Config.convert_big_decimal
            val.to_f
          else
            val
          end
        when Hash
          undump_hash(val)
        when Array
          val.map { |v| undump_hash_value(v) }
        else
          val
        end
      end
    end

    class Base
      def initialize(options)
        @options = options
      end

      def process(value)
        value
      end
    end

    class StringUndumper < Base
    end

    class IntegerUndumper < Base
      def process(value)
        value.to_i
      end
    end

    class NumberUndumper < Base
    end

    class SetUndumper < Base
      ALLOWED_TYPES = %i[string integer number date datetime serialized].freeze

      def process(set)
        if @options.key?(:of)
          process_typed_collection(set)
        else
          set.is_a?(Set) ? set : Set.new(set)
        end
      end

      private

      def process_typed_collection(set)
        if allowed_type?
          undumper = Undumping.find_undumper(element_options)
          set.to_set { |el| undumper.process(el) }
        else
          raise ArgumentError, "Set element type #{element_type} isn't supported"
        end
      end

      def allowed_type?
        ALLOWED_TYPES.include?(element_type) || element_type.is_a?(Class)
      end

      def element_type
        if @options[:of].is_a?(Hash)
          @options[:of].keys.first
        else
          @options[:of]
        end
      end

      def element_options
        if @options[:of].is_a?(Hash)
          @options[:of][element_type].dup.tap do |options|
            options[:type] = element_type
          end
        else
          { type: element_type }
        end
      end
    end

    class ArrayUndumper < Base
      ALLOWED_TYPES = %i[string integer number date datetime serialized].freeze

      def process(array)
        if @options.key?(:of)
          process_typed_collection(array)
        else
          array.is_a?(Array) ? array : Array(array)
        end
      end

      private

      def process_typed_collection(array)
        if allowed_type?
          undumper = Undumping.find_undumper(element_options)
          array.map { |el| undumper.process(el) }
        else
          raise ArgumentError, "Array element type #{element_type} isn't supported"
        end
      end

      def allowed_type?
        ALLOWED_TYPES.include?(element_type) || element_type.is_a?(Class)
      end

      def element_type
        if @options[:of].is_a?(Hash)
          @options[:of].keys.first
        else
          @options[:of]
        end
      end

      def element_options
        if @options[:of].is_a?(Hash)
          @options[:of][element_type].dup.tap do |options|
            options[:type] = element_type
          end
        else
          { type: element_type }
        end
      end
    end

    class MapUndumper < Base
      def process(value)
        UndumpHashHelper.undump_hash(value)
      end
    end

    class DateTimeUndumper < Base
      def process(value)
        return value if value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(Time)

        use_string_format = if @options[:store_as_string].nil?
                              Dynamoid.config.store_datetime_as_string
                            else
                              @options[:store_as_string]
                            end
        value = DateTime.iso8601(value).to_time.to_i if use_string_format
        ApplicationTimeZone.at(value)
      end
    end

    class DateUndumper < Base
      def process(value)
        use_string_format = if @options[:store_as_string].nil?
                              Dynamoid.config.store_date_as_string
                            else
                              @options[:store_as_string]
                            end

        if use_string_format
          Date.iso8601(value)
        else
          Dynamoid::Persistence::UNIX_EPOCH_DATE + value.to_i
        end
      end
    end

    class RawUndumper < Base
      def process(value)
        if value.is_a?(Hash)
          UndumpHashHelper.undump_hash(value)
        else
          value
        end
      end
    end

    class SerializedUndumper < Base
      # We must use YAML.safe_load in Ruby 3.1 to handle serialized Set class
      minimum_ruby_version = ->(version) { Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(version) }
      # Once we drop support for Rubies older than 2.6 we can remove this conditional (with major version bump)!
      # YAML_SAFE_LOAD = minimum_ruby_version.call("2.6")
      # But we don't want to change behavior for Ruby <= 3.0 that has been using the gem, without a major version bump
      YAML_SAFE_LOAD = minimum_ruby_version.call('3.1')

      def process(value)
        if @options[:serializer]
          @options[:serializer].load(value)
        elsif YAML_SAFE_LOAD
          # The classes listed in permitted classes are added to the default set of "safe loadable" classes.
          # TrueClass
          # FalseClass
          # NilClass
          # Integer
          # Float
          # String
          # Array
          # Hash
          YAML.safe_load(value, permitted_classes: [Symbol, Set, Date, Time, DateTime])
        else
          YAML.load(value)
        end
      end
    end

    class BooleanUndumper < Base
      STRING_VALUES = %w[t f].freeze

      def process(value)
        store_as_boolean = if @options[:store_as_native_boolean].nil?
                             Dynamoid.config.store_boolean_as_native
                           else
                             @options[:store_as_native_boolean]
                           end
        if store_as_boolean
          !!value
        elsif STRING_VALUES.include?(value)
          value == 't'
        else
          raise ArgumentError, 'Boolean column neither true nor false'
        end
      end
    end

    class BinaryUndumper < Base
      def process(value)
        store_as_binary = if @options[:store_as_native_binary].nil?
                            Dynamoid.config.store_binary_as_native
                          else
                            @options[:store_as_native_binary]
                          end

        if store_as_binary
          value.string # expect StringIO here
        else
          Base64.strict_decode64(value)
        end
      end
    end

    class CustomTypeUndumper < Base
      def process(value)
        field_class = @options[:type]

        unless field_class.respond_to?(:dynamoid_load)
          raise ArgumentError, "#{field_class} does not support serialization for Dynamoid."
        end

        field_class.dynamoid_load(value)
      end
    end
  end
end
