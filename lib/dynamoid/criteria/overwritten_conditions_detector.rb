# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class OverwrittenConditionsDetector
      def initialize(conditions, conditions_new)
        @conditions = conditions
        @new_conditions = conditions_new
        @overwritten_keys = overwritten_keys
      end

      def found?
        @overwritten_keys.present?
      end

      def warning_message
        return unless found?

        'Where conditions may contain only one condition for an attribute. ' \
          "Following conditions are ignored: #{ignored_conditions}"
      end

      private

      def overwritten_keys
        new_fields = @new_conditions.keys.map(&method(:key_to_field))
        @conditions.keys.select { |key| key_to_field(key).in?(new_fields) }
      end

      def key_to_field(key)
        key.to_s.split('.')[0]
      end

      def ignored_conditions
        @conditions.slice(*@overwritten_keys.map(&:to_sym))
      end
    end
  end
end
