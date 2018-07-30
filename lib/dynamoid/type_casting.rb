# frozen_string_literal: true

module Dynamoid
  module TypeCasting
    def self.cast_attributes(attributes, attributes_options)
      {}.tap do |h|
        attributes.symbolize_keys.each do |attribute, value|
          h[attribute] = cast_field(value, attributes_options[attribute])
        end
      end
    end

    def self.cast_field(value, options)
      return value if options.nil?
      return nil if value.nil?

      type_caster = find_type_caster(options)
      if type_caster.nil?
        raise ArgumentError, "Unknown type #{options[:type]}"
      end

      type_caster.process(value)
    end

    def self.find_type_caster(options)
      type_caster_class = case options[:type]
                          when :string     then StringTypeCaster
                          when :integer    then IntegerTypeCaster
                          when :number     then NumberTypeCaster
                          when :set        then SetTypeCaster
                          when :array      then ArrayTypeCaster
                          when :datetime   then DateTimeTypeCaster
                          when :date       then DateTypeCaster
                          when :raw        then RawTypeCaster
                          when :serialized then SerializedTypeCaster
                          when :boolean    then BooleanTypeCaster
                          when Class       then CustomTypeCaster
                          end

      if type_caster_class.present?
        type_caster_class.new(options)
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

    class StringTypeCaster < Base
      def process(value)
        if value == true
          't'
        elsif value == false
          'f'
        elsif value.is_a? String
          value.dup
        else
          value.to_s
        end
      end
    end

    class IntegerTypeCaster < Base
      def process(value)
        if value == true
          1
        elsif value == false
          0
        elsif value.is_a?(String) && value.blank?
          nil
        elsif value.is_a?(Float) && !value.finite?
          nil
        elsif !value.respond_to?(:to_i)
          nil
        else
          value.to_i
        end
      end
    end

    class NumberTypeCaster < Base
      def process(value)
        if value == true
          1
        elsif value == false
          0
        elsif value.is_a?(Symbol)
          value.to_s.to_d
        elsif value.is_a?(String) && value.blank?
          nil
        elsif value.is_a?(Float) && !value.finite?
          nil
        elsif !(value.respond_to?(:to_d))
          nil
        else
          value.to_d
        end
      end
    end

    class SetTypeCaster < Base
      def process(value)
        if value.is_a?(Set)
          value.dup
        elsif value.respond_to?(:to_set)
          value.to_set
        else
          nil
        end
      end
    end

    class ArrayTypeCaster < Base
      def process(value)
        if value.is_a?(Array)
          value.dup
        elsif value.respond_to?(:to_a)
          value.to_a
        else
          nil
        end
      end
    end

    class DateTimeTypeCaster < Base
      def process(value)
        if !value.respond_to?(:to_datetime)
          nil
        elsif value.is_a?(String)
          dt = DateTime.parse(value) rescue nil
          if dt
            seconds = string_utc_offset(value) || ApplicationTimeZone.utc_offset
            offset = seconds_to_offset(seconds)
            DateTime.new(dt.year, dt.mon, dt.mday, dt.hour, dt.min, dt.sec, offset)
          end
        else
          value.to_datetime
        end
      end

      private

      def string_utc_offset(string)
        Date._parse(string)[:offset]
      end

      # 3600 -> "+01:00"
      def seconds_to_offset(seconds)
        ActiveSupport::TimeZone.seconds_to_utc_offset(seconds)
      end
    end

    class DateTypeCaster < Base
      def process(value)
        if !value.respond_to?(:to_date)
          nil
        else
          begin
            value.to_date
          rescue ArgumentError
          end
        end
      end
    end

    class RawTypeCaster < Base
    end

    class SerializedTypeCaster < Base
    end

    class BooleanTypeCaster < Base
      def process(value)
        if value == ''
          nil
        elsif [false, 'false', 'FALSE', 0, '0', 'f', 'F', 'off', 'OFF'].include? value
          false
        else
          true
        end
      end
    end

    class CustomTypeCaster < Base
    end
  end
end
