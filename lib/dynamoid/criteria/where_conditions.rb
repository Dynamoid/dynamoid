# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class WhereConditions
      def initialize
        @conditions = []
      end

      def update(hash)
        @conditions << hash.symbolize_keys
      end

      def keys
        @conditions.flat_map(&:keys)
      end

      def empty?
        @conditions.empty?
      end

      def [](key)
        hash = @conditions.find { |h| h.key?(key) }

        return nil unless hash

        hash[key]
      end
    end
  end
end
