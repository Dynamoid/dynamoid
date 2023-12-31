# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class NonexistentFieldsDetector
      def initialize(conditions, source)
        @conditions = conditions
        @source = source
        @nonexistent_fields = nonexistent_fields
      end

      def found?
        @nonexistent_fields.present?
      end

      def warning_message
        return unless found?

        fields_list = @nonexistent_fields.map { |s| "`#{s}`" }.join(', ')
        count = @nonexistent_fields.size

        'where conditions contain nonexistent ' \
          "field #{'name'.pluralize(count)} #{fields_list}"
      end

      private

      def nonexistent_fields
        fields_from_conditions - fields_existent
      end

      def fields_from_conditions
        @conditions.keys.map { |s| s.to_s.split('.')[0].to_sym }
      end

      def fields_existent
        @source.attributes.keys.map(&:to_sym)
      end
    end
  end
end
