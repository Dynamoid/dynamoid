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
          clauses = []

          @conditions.each do |conditions|
            if conditions.is_a? Hash
              clauses << build_for_hash(conditions) unless conditions.empty?
            elsif conditions.is_a? Array
              query, placeholders = conditions
              clauses << build_for_string(query, placeholders)
            else
              raise ArgumentError, "expected Hash or Array but actual value is #{conditions}"
            end
          end

          @expression = clauses.join(' AND ')
        end

        def build_for_hash(hash)
          clauses = hash.map do |name, attribute_conditions|
            attribute_conditions.map do |operator, value|
              # replace attribute names with placeholders unconditionally to support
              # - special characters (e.g. '.', ':', and '#') and
              # - leading '_'
              # See
              # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.NamingRules
              # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.ExpressionAttributeNames.html#Expressions.ExpressionAttributeNames.AttributeNamesContainingSpecialCharacters
              name_placeholder = name_placeholder_for(name)

              case operator
              when :eq
                "#{name_placeholder} = #{value_placeholder_for(value)}"
              when :ne
                "#{name_placeholder} <> #{value_placeholder_for(value)}"
              when :gt
                "#{name_placeholder} > #{value_placeholder_for(value)}"
              when :lt
                "#{name_placeholder} < #{value_placeholder_for(value)}"
              when :gte
                "#{name_placeholder} >= #{value_placeholder_for(value)}"
              when :lte
                "#{name_placeholder} <= #{value_placeholder_for(value)}"
              when :between
                "#{name_placeholder} BETWEEN #{value_placeholder_for(value[0])} AND #{value_placeholder_for(value[1])}"
              when :begins_with
                "begins_with (#{name_placeholder}, #{value_placeholder_for(value)})"
              when :in
                list = value.map(&method(:value_placeholder_for)).join(' , ')
                "#{name_placeholder} IN (#{list})"
              when :contains
                "contains (#{name_placeholder}, #{value_placeholder_for(value)})"
              when :not_contains
                "NOT contains (#{name_placeholder}, #{value_placeholder_for(value)})"
              when :null
                "attribute_not_exists (#{name_placeholder})"
              when :not_null
                "attribute_exists (#{name_placeholder})"
              end
            end
          end.flatten

          if clauses.empty?
            nil
          else
            clauses.join(' AND ')
          end
        end

        def build_for_string(query, placeholders)
          placeholders.each do |(k, v)|
            k = k.to_s
            k = ":#{k}" unless k.start_with?(':')
            @value_placeholders[k] = v
          end

          "(#{query})"
        end

        def name_placeholder_for(name)
          placeholder = @name_placeholder_sequence.call
          @name_placeholders[placeholder] = name
          placeholder
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
