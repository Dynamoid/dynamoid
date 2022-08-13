# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      # Mimics behavior of the yielded object on DynamoDB's update_item API (high level).
      class ItemUpdater
        ADD    = 'ADD'
        DELETE = 'DELETE'
        PUT    = 'PUT'

        attr_reader :table, :key, :range_key

        def initialize(table, key, range_key = nil)
          @table = table
          @key = key
          @range_key = range_key
          @additions = {}
          @deletions = {}
          @updates   = {}
        end

        #
        # Adds the given values to the values already stored in the corresponding columns.
        # The column must contain a Set or a number.
        #
        # @param [Hash] values keys of the hash are the columns to update, values
        #                      are the values to add. values must be a Set, Array, or Numeric
        #
        def add(values)
          @additions.merge!(sanitize_attributes(values))
        end

        #
        # Removes values from the sets of the given columns
        #
        # @param [Hash] values keys of the hash are the columns, values are Arrays/Sets of items
        #               to remove
        #
        def delete(values)
          @deletions.merge!(sanitize_attributes(values))
        end

        #
        # Replaces the values of one or more attributes
        #
        def set(values)
          @updates.merge!(sanitize_attributes(values))
        end

        #
        # Returns an AttributeUpdates hash suitable for passing to the V2 Client API
        #
        def attribute_updates
          result = {}

          @additions.each do |k, v|
            result[k] = {
              action: ADD,
              value: v
            }
          end

          @deletions.each do |k, v|
            result[k] = {
              action: DELETE
            }
            result[k][:value] = v unless v.nil?
          end

          @updates.each do |k, v|
            result[k] = {
              action: PUT,
              value: v
            }
          end

          result
        end

        private

        def sanitize_attributes(attributes)
          attributes.transform_values do |v|
            v.is_a?(Hash) ? v.stringify_keys : v
          end
        end
      end
    end
  end
end
