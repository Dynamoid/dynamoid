# frozen_string_literal: true

module Dynamoid
  # @private
  module Dumping
    def self.dump_attributes(attributes, attributes_options)
      {}.tap do |h|
        attributes.each do |attribute, value|
          h[attribute] = dump_field(value, attributes_options[attribute])
        end
      end
    end

    def self.dump_field(value, options)
      return nil if value.nil?

      dumper = find_dumper(options)

      if dumper.nil?
        raise ArgumentError, "Unknown type #{options[:type]}"
      end

      dumper.process(value)
    end

    def self.find_dumper(options)
      dumper_class = case options[:type]
                     when :string     then StringDumper
                     when :integer    then IntegerDumper
                     when :number     then NumberDumper
                     when :set        then SetDumper
                     when :array      then ArrayDumper
                     when :map        then MapDumper
                     when :datetime   then DateTimeDumper
                     when :date       then DateDumper
                     when :serialized then SerializedDumper
                     when :raw        then RawDumper
                     when :boolean    then BooleanDumper
                     when :binary     then BinaryDumper
                     when Class       then CustomTypeDumper
                     end

      if dumper_class.present?
        dumper_class.new(options)
      end
    end

    module DeepSanitizeHelper
      extend self

      def deep_sanitize(value)
        case value
        when Hash
          sanitize_hash(value).transform_values { |v| deep_sanitize(v) }
        when Array
          sanitize_array(value).map { |v| deep_sanitize(v) }
        else
          value
        end
      end

      private

      def sanitize_hash(hash)
        hash.transform_values { |v| invalid_value?(v) ? nil : v }
      end

      def sanitize_array(array)
        array.map { |v| invalid_value?(v) ? nil : v }
      end

      def invalid_value?(value)
        (value.is_a?(Set) && value.empty?) ||
          (value.is_a?(String) && value.empty? && Config.store_empty_string_as_nil)
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

    # string -> string
    class StringDumper < Base
      def process(string)
        return nil if string.nil?
        return nil if string.empty? && Config.store_empty_string_as_nil

        string
      end
    end

    # integer -> number
    class IntegerDumper < Base
    end

    # number -> number
    class NumberDumper < Base
    end

    # set -> set
    class SetDumper < Base
      ALLOWED_TYPES = %i[string integer number date datetime serialized].freeze

      def process(set)
        return nil if set.is_a?(Set) && set.empty?

        if @options.key?(:of)
          process_typed_collection(set)
        else
          set
        end
      end

      private

      def process_typed_collection(set)
        if allowed_type?
          # StringDumper may replace "" with nil so we cannot distinguish it from an explicit nil
          if element_type == :string && Config.store_empty_string_as_nil
            set.reject! { |s| s && s.empty? }
          end

          dumper = Dumping.find_dumper(element_options)
          result = set.map { |el| dumper.process(el) }
          result.to_set
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

    # array -> array
    class ArrayDumper < Base
      ALLOWED_TYPES = %i[string integer number date datetime serialized].freeze

      def process(array)
        if @options.key?(:of)
          process_typed_collection(array)
        else
          array
        end
      end

      private

      def process_typed_collection(array)
        if allowed_type?
          # StringDumper may replace "" with nil so we cannot distinguish it from an explicit nil
          if element_type == :string && Config.store_empty_string_as_nil
            array.reject! { |s| s && s.empty? }
          end

          dumper = Dumping.find_dumper(element_options)
          array.map { |el| dumper.process(el) }
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

    # hash -> map
    class MapDumper < Base
      def process(value)
        DeepSanitizeHelper.deep_sanitize(value)
      end
    end

    # datetime -> integer/string
    class DateTimeDumper < Base
      def process(value)
        value.nil? ? nil : format_datetime(value, @options)
      end

      private

      def format_datetime(value, options)
        use_string_format = if options[:store_as_string].nil?
                              Dynamoid.config.store_datetime_as_string
                            else
                              options[:store_as_string]
                            end

        if use_string_format
          value_in_time_zone = Dynamoid::DynamodbTimeZone.in_time_zone(value)
          value_in_time_zone.iso8601
        else
          unless value.respond_to?(:to_i) && value.respond_to?(:nsec)
            value = value.to_time
          end
          BigDecimal(format('%d.%09d', value.to_i, value.nsec))
        end
      end
    end

    # date -> integer/string
    class DateDumper < Base
      def process(value)
        value.nil? ? nil : format_date(value, @options)
      end

      private

      def format_date(value, options)
        use_string_format = if options[:store_as_string].nil?
                              Dynamoid.config.store_date_as_string
                            else
                              options[:store_as_string]
                            end

        if use_string_format
          value.to_date.iso8601
        else
          (value.to_date - Dynamoid::Persistence::UNIX_EPOCH_DATE).to_i
        end
      end
    end

    # any standard Ruby object -> self
    class RawDumper < Base
      def process(value)
        DeepSanitizeHelper.deep_sanitize(value)
      end
    end

    # object -> string
    class SerializedDumper < Base
      def process(value)
        @options[:serializer] ? @options[:serializer].dump(value) : value.to_yaml
      end
    end

    # True/False -> True/False/string
    class BooleanDumper < Base
      def process(value)
        unless value.nil?
          store_as_boolean = if @options[:store_as_native_boolean].nil?
                               Dynamoid.config.store_boolean_as_native
                             else
                               @options[:store_as_native_boolean]
                             end
          if store_as_boolean
            !!value
          else
            value.to_s[0] # => "f" or "t"
          end
        end
      end
    end

    # string -> string
    class BinaryDumper < Base
      def process(value)
        Base64.strict_encode64(value)
      end
    end

    # any object -> string
    class CustomTypeDumper < Base
      def process(value)
        field_class = @options[:type]

        if value.respond_to?(:dynamoid_dump)
          value.dynamoid_dump
        elsif field_class.respond_to?(:dynamoid_dump)
          field_class.dynamoid_dump(value)
        else
          raise ArgumentError, "Neither #{field_class} nor #{value} supports serialization for Dynamoid."
        end
      end
    end
  end
end
