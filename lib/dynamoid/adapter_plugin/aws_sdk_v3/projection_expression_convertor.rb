# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      class ProjectionExpressionConvertor
        attr_reader :expression, :name_placeholders

        def initialize(names, name_placeholders, name_placeholder_sequence)
          @names = names
          @name_placeholders = name_placeholders.dup
          @name_placeholder_sequence = name_placeholder_sequence

          build
        end

        private

        def build
          return if @names.nil? || @names.empty?

          clauses = @names.map do |name|
            # replace attribute names with placeholders unconditionally to support
            # - special characters (e.g. '.', ':', and '#') and
            # - leading '_'
            # See
            # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.NamingRules
            # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.ExpressionAttributeNames.html#Expressions.ExpressionAttributeNames.AttributeNamesContainingSpecialCharacters
            placeholder = @name_placeholder_sequence.call
            @name_placeholders[placeholder] = name
            placeholder
          end

          @expression = clauses.join(' , ')
        end
      end
    end
  end
end
