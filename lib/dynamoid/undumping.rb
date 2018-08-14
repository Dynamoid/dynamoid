# frozen_string_literal: true

module Dynamoid
  module Undumping
    def self.undump_attributes(attributes, attributes_options)
      {}.tap do |h|
        attributes.symbolize_keys.each do |attribute, value|
          h[attribute] = undump_field(value, attributes_options[attribute])
        end
      end
    end

    def self.undump_field(value, options)
      undumper = find_undumper(options)

      if undumper.nil?
        raise ArgumentError, "Unknown type #{options[:type]}"
      end

      return nil if value.nil?
      undumper.process(value)
    end

    def self.find_undumper(options)
      undumper_class = case options[:type]
                       when :string     then StringUndumper
                       when :integer    then IntegerUndumper
                       when :number     then NumberUndumper
                       when :set        then SetUndumper
                       when :array      then ArrayUndumper
                       when :datetime   then DateTimeUndumper
                       when :date       then DateUndumper
                       when :raw        then RawUndumper
                       when :serialized then SerializedUndumper
                       when :boolean    then BooleanUndumper
                       when Class       then CustomTypeUndumper
                       end

      if undumper_class.present?
        undumper_class.new(options)
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
      def process(value)
        case @options[:of]
        when :integer
          value.map { |v| Integer(v) }.to_set
        when :number
          value.map { |v| BigDecimal(v.to_s) }.to_set
        else
          value.is_a?(Set) ? value : Set.new(value)
        end
      end
    end

    class ArrayUndumper < Base
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
          undump_hash(value)
        else
          value
        end
      end

      private

      def undump_hash(hash)
        {}.tap do |h|
          hash.each { |key, value| h[key.to_sym] = undump_hash_value(value) }
        end
      end

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

    class SerializedUndumper < Base
      def process(value)
        if @options[:serializer]
          @options[:serializer].load(value)
        else
          YAML.load(value)
        end
      end
    end

    class BooleanUndumper < Base
      def process(value)
        store_as_boolean = if @options[:store_as_native_boolean].nil?
                             Dynamoid.config.store_boolean_as_native
                           else
                             @options[:store_as_native_boolean]
                           end
        if store_as_boolean
          !!value
        elsif ['t', 'f'].include?(value)
          value == 't'
        else
          raise ArgumentError, 'Boolean column neither true nor false'
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
