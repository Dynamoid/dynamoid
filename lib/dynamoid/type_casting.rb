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
        value.to_s
      end
    end

    class IntegerTypeCaster < Base
      def process(value)
        Integer(value)
      end
    end

    class NumberTypeCaster < Base
      def process(value)
        BigDecimal(value.to_s)
      end
    end

    class SetTypeCaster < Base
      def process(value)
        value.is_a?(Set) ? value : Set.new(value)
      end
    end

    class ArrayTypeCaster < Base
      def process(value)
        value.to_a
      end
    end

    class DateTimeTypeCaster < Base
      def process(value)
        value
      end
    end

    class DateTypeCaster < Base
      def process(value)
        value
      end
    end

    class RawTypeCaster < Base
    end

    class SerializedTypeCaster < Base
    end

    class BooleanTypeCaster < Base
      def process(value)
        if ['t', true].include? value
          true
        elsif ['f', false].include? value
          false
        else
          nil
        end
      end
    end

    class CustomTypeCaster < Base
    end
  end
end
