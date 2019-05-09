# frozen_string_literal: true

module Dynamoid #:nodoc:
  module Criteria
    class KeyFieldsDetector
      attr_reader :hash_key, :range_key, :index_name

      def initialize(query, source)
        @query = query
        @source = source

        detect_keys
      end

      def key_present?
        @hash_key.present?
      end

      private

      def detect_keys
        query_keys = @query.keys.collect { |k| k.to_s.split('.').first }

        # See if querying based on table hash key
        if @query.keys.map(&:to_s).include?(@source.hash_key.to_s)
          @hash_key = @source.hash_key

          # Use table's default range key
          if query_keys.include?(@source.range_key.to_s)
            @range_key = @source.range_key
            return
          end

          # See if can use any local secondary index range key
          # Chooses the first LSI found that can be utilized for the query
          @source.local_secondary_indexes.each do |_, lsi|
            next unless query_keys.include?(lsi.range_key.to_s)

            @range_key = lsi.range_key
            @index_name = lsi.name
          end

          return
        end

        # See if can use any global secondary index
        # Chooses the first GSI found that can be utilized for the query
        # But only do so if projects ALL attributes otherwise we won't
        # get back full data
        @source.global_secondary_indexes.each do |_, gsi|
          next unless @query.keys.map(&:to_s).include?(gsi.hash_key.to_s) && gsi.projected_attributes == :all
          next if @range_key.present? && !query_keys.include?(gsi.range_key.to_s)

          @hash_key = gsi.hash_key
          @range_key = gsi.range_key
          @index_name = gsi.name
        end
      end
    end
  end
end
