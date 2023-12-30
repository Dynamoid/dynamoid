# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      class FilterExpressionConvertor
        attr_reader :expression, :name_placeholders, :value_placeholders

        def initialize(conditions, name_placeholders, value_placeholders, name_placeholder_sequence, value_placeholder_sequence)
          @conditions = conditions
          @name_placeholders = name_placeholders.dup
          @value_placeholders = value_placeholders.dup
          @name_placeholder_sequence = name_placeholder_sequence
          @value_placeholder_sequence = value_placeholder_sequence

          build
        end

        private

        def build
          clauses = @conditions.map do |path, attribute_conditions|
            attribute_conditions.map do |operator, value|
              name_or_placeholder = name_or_placeholder_for(path)

              case operator
              when :eq
                "#{name_or_placeholder} = #{value_placeholder_for(value)}"
              when :ne
                "#{name_or_placeholder} <> #{value_placeholder_for(value)}"
              when :gt
                "#{name_or_placeholder} > #{value_placeholder_for(value)}"
              when :lt
                "#{name_or_placeholder} < #{value_placeholder_for(value)}"
              when :gte
                "#{name_or_placeholder} >= #{value_placeholder_for(value)}"
              when :lte
                "#{name_or_placeholder} <= #{value_placeholder_for(value)}"
              when :between
                "#{name_or_placeholder} BETWEEN #{value_placeholder_for(value[0])} AND #{value_placeholder_for(value[1])}"
              when :begins_with
                "begins_with (#{name_or_placeholder}, #{value_placeholder_for(value)})"
              when :in
                list = value.map(&method(:value_placeholder_for)).join(' , ')
                "#{name_or_placeholder} IN (#{list})"
              when :contains
                "contains (#{name_or_placeholder}, #{value_placeholder_for(value)})"
              when :not_contains
                "NOT contains (#{name_or_placeholder}, #{value_placeholder_for(value)})"
              when :null
                "attribute_not_exists (#{name_or_placeholder})"
              when :not_null
                "attribute_exists (#{name_or_placeholder})"
              end
            end
          end.flatten

          @expression = clauses.join(' AND ')
        end

        # Replace reserved words with placeholders
        def name_or_placeholder_for(path) # TODO: support List elements
          sections = path.to_s.split('.')

          sanitized = sections.map do |name|
            unless name.upcase.to_sym.in?(Dynamoid::AdapterPlugin::AwsSdkV3::RESERVED_WORDS)
              next name
            end

            placeholder = @name_placeholder_sequence.call
            @name_placeholders[placeholder] = name
            placeholder
          end

          sanitized.join('.')
        end

        def value_placeholder_for(value)
          placeholder = @value_placeholder_sequence.call
          @value_placeholders[placeholder] = value
          placeholder
        end
      end
    end
  end
end
