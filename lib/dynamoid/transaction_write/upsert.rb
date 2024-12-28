# frozen_string_literal: true

require_relative 'base'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  class TransactionWrite
    class Upsert < Base
      def initialize(model_class, hash_key, range_key, attributes)
        super()

        @model_class = model_class
        @hash_key = hash_key
        @range_key = range_key
        @attributes = attributes
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
        attributes_to_assign = @attributes.except(@model_class.hash_key, @model_class.range_key)
        attributes_to_assign.empty? && !@model_class.timestamps_enabled?
      end

      def observable_by_user_result
        nil
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

        {
          update: {
            key: key,
            table_name: @model_class.table_name,
            update_expression: update_expression,
            expression_attribute_names: expression_attribute_names,
            expression_attribute_values: expression_attribute_values
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
