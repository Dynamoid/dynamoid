# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      # Represents a table. Exposes data from the "DescribeTable" API call, and also
      # provides methods for coercing values to the proper types based on the table's schema data
      class Table
        attr_reader :schema

        #
        # @param [Hash] schema Data returns from a "DescribeTable" call
        #
        def initialize(schema)
          @schema = schema[:table]
          @local = false
        end

        def range_key
          @range_key ||= schema[:key_schema].find { |d| d[:key_type] == RANGE_KEY }.try(:attribute_name)
        end

        def range_type
          range_type ||= schema[:attribute_definitions].find do |d|
            d[:attribute_name] == range_key
          end.try(:fetch, :attribute_type, nil)
        end

        def hash_key
          @hash_key ||= schema[:key_schema].find { |d| d[:key_type] == HASH_KEY }.try(:attribute_name).to_sym
        end

        #
        # Returns the API type (e.g. "N", "S") for the given column, if the schema defines it,
        # nil otherwise
        #
        def col_type(col)
          col = col.to_s
          col_def = schema[:attribute_definitions].find { |d| d[:attribute_name] == col.to_s }
          col_def && col_def[:attribute_type]
        end

        def item_count
          schema[:item_count]
        end

        def name
          schema[:table_name]
        end

        def arn
          schema[:table_arn]
        end

        def local!
          @local = true
        end

        def local?
          @local
        end
      end
    end
  end
end
