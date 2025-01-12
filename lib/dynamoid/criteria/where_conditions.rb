# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class WhereConditions
      attr_reader :string_conditions

      def initialize
        @hash_conditions = []
        @string_conditions = []
      end

      def update_with_hash(hash)
        @hash_conditions << hash.symbolize_keys
      end

      def update_with_string(query, placeholders)
        @string_conditions << [query, placeholders]
      end

      def keys
        @hash_conditions.flat_map(&:keys)
      end

      def empty?
        @hash_conditions.empty? && @string_conditions.empty?
      end

      def [](key)
        hash = @hash_conditions.find { |h| h.key?(key) }
        hash[key] if hash
      end
    end
  end
end
