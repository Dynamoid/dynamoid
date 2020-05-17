# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class IgnoredConditionsDetector
      def initialize(conditions)
        @conditions = conditions
        @ignored_keys = ignored_keys
      end

      def found?
        @ignored_keys.present?
      end

      def warning_message
        return unless found?

        'Where conditions may contain only one condition for an attribute. ' \
          "Following conditions are ignored: #{ignored_conditions}"
      end

      private

      def ignored_keys
        @conditions.keys
          .group_by(&method(:key_to_field))
          .select { |_, ary| ary.size > 1 }
          .flat_map { |_, ary| ary[0..-2] }
      end

      def key_to_field(key)
        key.to_s.split('.')[0]
      end

      def ignored_conditions
        @conditions.slice(*@ignored_keys)
      end
    end
  end
end
