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
            if name.upcase.in?(Dynamoid::AdapterPlugin::AwsSdkV3::RESERVED_WORDS)
              placeholder = @name_placeholder_sequence.call
              @name_placeholders[placeholder] = name
              placeholder
            else
              name.to_s
            end
          end

          @expression = clauses.join(' , ')
        end
      end
    end
  end
end
