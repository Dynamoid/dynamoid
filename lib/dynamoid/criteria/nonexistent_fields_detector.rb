# frozen_string_literal: true

module Dynamoid
  module Criteria
    class NonexistentFieldsDetector
      def initialize(conditions, source)
        @conditions = conditions
        @source = source
      end

      def fields
        fields_from_conditions - fields_existent
      end

      private

      def fields_from_conditions
        @conditions.keys.map do |s|
          name, _ = s.to_s.split('.')
          name
        end.map(&:to_sym)
      end

      def fields_existent
        @source.attributes.keys.map(&:to_sym)
      end
    end
  end
end
