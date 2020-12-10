# frozen_string_literal: true

module Dynamoid
  module Criteria
    # @private
    class KeyFieldsDetector
      class Query
        def initialize(query_hash)
          @query_hash = query_hash
          @fields_with_operator = query_hash.keys.map(&:to_s)
          @fields = query_hash.keys.map(&:to_s).map { |s| s.split('.').first }
        end

        def contain_only?(field_names)
          (@fields - field_names.map(&:to_s)).blank?
        end

        def contain?(field_name)
          @fields.include?(field_name.to_s)
        end

        def contain_with_eq_operator?(field_name)
          @fields_with_operator.include?(field_name.to_s)
        end
      end

      def initialize(query, source, forced_index_name: nil)
        @query = query
        @source = source
        @query = Query.new(query)
        @forced_index_name = forced_index_name
        @result = find_keys_in_query
      end

      def non_key_present?
        !@query.contain_only?([hash_key, range_key].compact)
      end

      def key_present?
        @result.present?
      end

      def hash_key
        @result && @result[:hash_key]
      end

      def range_key
        @result && @result[:range_key]
      end

      def index_name
        @result && @result[:index_name]
      end

      private

      def find_keys_in_query
        return match_forced_index if @forced_index_name

        match_table_and_sort_key ||
          match_local_secondary_index ||
          match_global_secondary_index_and_sort_key ||
          match_table ||
          match_global_secondary_index
      end

      # Use table's default range key
      def match_table_and_sort_key
        return unless @query.contain_with_eq_operator?(@source.hash_key)
        return unless @source.range_key

        if @query.contain?(@source.range_key)
          {
            hash_key: @source.hash_key,
            range_key: @source.range_key
          }
        end
      end

      # See if can use any local secondary index range key
      # Chooses the first LSI found that can be utilized for the query
      def match_local_secondary_index
        return unless @query.contain_with_eq_operator?(@source.hash_key)

        lsi = @source.local_secondary_indexes.values.find do |i|
          @query.contain?(i.range_key)
        end

        if lsi.present?
          {
            hash_key: @source.hash_key,
            range_key: lsi.range_key,
            index_name: lsi.name,
          }
        end
      end

      # See if can use any global secondary index
      # Chooses the first GSI found that can be utilized for the query
      # GSI with range key involved into query conditions has higher priority
      # But only do so if projects ALL attributes otherwise we won't
      # get back full data
      def match_global_secondary_index_and_sort_key
        gsi = @source.global_secondary_indexes.values.find do |i|
          @query.contain_with_eq_operator?(i.hash_key) && i.projected_attributes == :all &&
            @query.contain?(i.range_key)
        end

        if gsi.present?
          {
            hash_key: gsi.hash_key,
            range_key: gsi.range_key,
            index_name: gsi.name,
          }
        end
      end

      def match_table
        return unless @query.contain_with_eq_operator?(@source.hash_key)

        {
          hash_key: @source.hash_key,
        }
      end

      def match_global_secondary_index
        gsi = @source.global_secondary_indexes.values.find do |i|
          @query.contain_with_eq_operator?(i.hash_key) && i.projected_attributes == :all
        end

        if gsi.present?
          {
            hash_key: gsi.hash_key,
            range_key: gsi.range_key,
            index_name: gsi.name,
          }
        end
      end

      def match_forced_index
        idx = @source.find_index_by_name(@forced_index_name)

        {
          hash_key: idx.hash_key,
          range_key: idx.range_key,
          index_name: idx.name,
        }
      end
    end
  end
end
