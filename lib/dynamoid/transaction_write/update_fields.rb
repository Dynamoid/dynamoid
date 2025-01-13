# frozen_string_literal: true

require_relative 'base'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  class TransactionWrite
    class UpdateFields < Base
      def initialize(model_class, hash_key, range_key, attributes)
        super()

        @model_class = model_class
        @hash_key = hash_key
        @range_key = range_key
        @attributes = attributes || {}

        @item_updater = ItemUpdater.new

        yield(self) if block_given?
      end

      def on_registration
        validate_primary_key!
        Dynamoid::Persistence::UpdateValidations.validate_attributes_exist(@model_class, @attributes)
      end

      def on_commit; end

      def on_rollback; end

      def aborted?
        false
      end

      def skipped?
        @attributes.empty? && @item_updater.empty?
      end

      def observable_by_user_result
        nil
      end

      # sets a value in the attributes
      def set(attributes)
        @attributes.merge!(attributes)
      end

      # adds to array of fields for use in REMOVE update expression
      def remove(field)
        @item_updater.remove(field)
      end

      # increments a number or adds to a set, starts at 0 or [] if it doesn't yet exist
      def add(values)
        @item_updater.add(values)
      end

      # deletes a value or values from a set type or simply sets a field to nil
      def delete(field_or_values)
        @item_updater.delete(field_or_values)
      end

      def action_request
        # changed attributes to persist
        changes = @attributes.dup
        changes = add_timestamps(changes, skip_created_at: true)
        changes_dumped = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

        # primary key to look up an item to update
        key = { @model_class.hash_key => @hash_key }
        key[@model_class.range_key] = @range_key if @model_class.range_key?

        # Build UpdateExpression and keep names and values placeholders mapping
        # in ExpressionAttributeNames and ExpressionAttributeValues.
        update_expression_statements = []
        expression_attribute_names = {}
        expression_attribute_values = {}

        changes_dumped.each_with_index do |(name, value), i|
          name_placeholder = "#_n#{i}"
          value_placeholder = ":_s#{i}"

          update_expression_statements << "#{name_placeholder} = #{value_placeholder}"
          expression_attribute_names[name_placeholder] = name
          expression_attribute_values[value_placeholder] = value
        end

        update_expression = "SET #{update_expression_statements.join(', ')}"

        expression_attribute_names, update_expression = @item_updater.merge_update_expression(
          expression_attribute_names, expression_attribute_values, update_expression
        )

        # require primary key to exist
        condition_expression = "attribute_exists(#{@model_class.hash_key})"
        if @model_class.range_key?
          condition_expression += " AND attribute_exists(#{@model_class.range_key})"
        end

        {
          update: {
            key: key,
            table_name: @model_class.table_name,
            update_expression: update_expression,
            expression_attribute_names: expression_attribute_names,
            expression_attribute_values: expression_attribute_values,
            condition_expression: condition_expression
          }
        }
      end

      private

      def validate_primary_key!
        raise Dynamoid::Errors::MissingHashKey if @hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @range_key.nil?
      end

      def add_timestamps(attributes, skip_created_at: false)
        return attributes unless @model_class.timestamps_enabled?

        result = attributes.clone
        timestamp = DateTime.now.in_time_zone(Time.zone)
        result[:created_at] ||= timestamp unless skip_created_at
        result[:updated_at] ||= timestamp
        result
      end
    end
  end
end
