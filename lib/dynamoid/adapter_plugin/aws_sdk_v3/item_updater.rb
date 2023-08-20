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
        # @param [Hash|Symbol|String] values keys of the hash are the columns, values are Arrays/Sets of items
        #                                    to remove
        #
        def delete(values)
          if values.is_a?(Hash)
            @deletions.merge!(sanitize_attributes(values))
          else
            @deletions.merge!(values.to_s => nil)
          end
        end

        #
        # Replaces the values of one or more attributes
        #
        def set(values)
          values_sanitized = sanitize_attributes(values)

          if Dynamoid.config.store_attribute_with_nil_value
            @updates.merge!(values_sanitized)
          else
            # delete explicitly attributes if assigned nil value and configured
            # to not store nil values
            values_to_update = values_sanitized.select { |_, v| !v.nil? }
            values_to_delete = values_sanitized.select { |_, v| v.nil? }

            @updates.merge!(values_to_update)
            @deletions.merge!(values_to_delete)
          end

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

        # Keep in sync with AwsSdkV3.sanitize_item.
        #
        # The only difference is that to update item we need to track whether
        # attribute value is nil or not.
        def sanitize_attributes(attributes)
          attributes.transform_values do |v|
            if v.is_a?(Hash)
              v.stringify_keys
            elsif v.is_a?(Set) && v.empty?
              nil
            elsif v.is_a?(String) && v.empty?
              nil
            else
              v
            end
          end
        end
      end
    end
  end
end
