# frozen_string_literal: true

module Dynamoid #:nodoc:
  module Criteria
    class KeyFieldsDetector

      class Query
        def initialize(query_hash)
          @query_hash = query_hash
          @fields_with_operator = query_hash.keys.map(&:to_s)
          @fields = query_hash.keys.map(&:to_s).map { |s| s.split('.').first }
        end

        def contain?(field_name)
          @fields.include?(field_name.to_s)
        end

        def contain_with_eq_operator?(field_name)
          @fields_with_operator.include?(field_name.to_s)
        end
      end


      attr_reader :hash_key, :range_key, :index_name

      def initialize(query, source)
        @query = query
        @source = source
        @query = Query.new(query)

        detect_keys
      end

      def key_present?
        @hash_key.present?
      end

      private

      def detect_keys
        # See if querying based on table hash key
        if @query.contain_with_eq_operator?(@source.hash_key)
          @hash_key = @source.hash_key

          # Use table's default range key
          if @query.contain?(@source.range_key)
            @range_key = @source.range_key
            return
          end

          # See if can use any local secondary index range key
          # Chooses the first LSI found that can be utilized for the query
          @source.local_secondary_indexes.each do |_, lsi|
            next unless @query.contain?(lsi.range_key)

            @range_key = lsi.range_key
            @index_name = lsi.name
          end

          return if @range_key.present?
        end

        # See if can use any global secondary index
        # Chooses the last GSI found that can be utilized for the query
        # GSI with range key used in query has higher priority
        # But only do so if projects ALL attributes otherwise we won't
        # get back full data
        @source.global_secondary_indexes.each do |_, gsi|
          next unless @query.contain_with_eq_operator?(gsi.hash_key) && gsi.projected_attributes == :all
          next if @hash_key.present? && !@query.contain?(gsi.range_key)

          @hash_key = gsi.hash_key
          @range_key = gsi.range_key
          @index_name = gsi.name
        end
      end
    end
  end
end
