# frozen_string_literal: true

require_relative 'base'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  class TransactionWrite
    class UpdateFields < Base
      def initialize(model_class, hash_key, range_key, attributes, &block)
        super()

        @model_class = model_class
        @hash_key = hash_key
        @range_key = range_key
        @attributes = attributes || {}
        @block = block
      end

      def on_registration
        validate_primary_key!
        Dynamoid::Persistence::UpdateValidations.validate_attributes_exist(@model_class, @attributes)

        if @block
          @item_updater = ItemUpdater.new(@model_class)
          @block.call(@item_updater)
        end
      end

      def on_commit; end

      def on_rollback; end

      def aborted?
        false
      end

      def skipped?
        @attributes.empty? && (!@item_updater || @item_updater.empty?)
      end

      def observable_by_user_result
        nil
      end

      def action_request
        builder = UpdateRequestBuilder.new(@model_class)

        # primary key to look up an item to update
        builder.hash_key = dump_attribute(@model_class.hash_key, @hash_key)
        builder.range_key = dump_attribute(@model_class.range_key, @range_key) if @model_class.range_key?

        # changed attributes to persist
        changes = @attributes.dup
        changes = add_timestamps(changes, skip_created_at: true)
        changes_dumped = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

        builder.set_attributes(changes_dumped)

        # given a block
        if @item_updater
          builder.set_attributes(@item_updater.attributes_to_set)
          builder.remove_attributes(@item_updater.attributes_to_remove)

          @item_updater.attributes_to_add.each do |name, value|
            # The ADD section in UpdateExpressions requires values to be a
            # set to update a set attribute.
            # Allow specifying values as any Enumerable collection (e.g. Array).
            # Allow a single value not wrapped into a Set
            if @model_class.attributes[name][:type] == :set
              value = value.is_a?(Enumerable) ? Set.new(value) : Set[value]
            end

            builder.add_value(name, value)
          end

          @item_updater.attributes_to_delete.each do |name, value|
            # The DELETE section in UpdateExpressions requires values to be a
            # set to update a set attribute.
            # Allow specifying values as any Enumerable collection (e.g. Array).
            # Allow a single value not wrapped into a Set
            value = value.is_a?(Enumerable) ? Set.new(value) : Set[value]

            builder.delete_value(name, value)
          end
        end

        # require primary key to exist
        condition_expression = "attribute_exists(#{@model_class.hash_key})"
        if @model_class.range_key?
          condition_expression += " AND attribute_exists(#{@model_class.range_key})"
        end
        builder.condition_expression = condition_expression

        builder.request
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

      def dump_attribute(name, value)
        options = @model_class.attributes[name]
        Dumping.dump_field(value, options)
      end

      class UpdateRequestBuilder
        attr_writer :hash_key, :range_key, :condition_expression

        def initialize(model_class)
          @model_class = model_class

          @attributes_to_set = {}
          @attributes_to_add = {}
          @attributes_to_delete = {}
          @attributes_to_remove = []
          @condition_expression = nil
        end

        def set_attributes(attributes) # rubocop:disable Naming/AccessorMethodName
          @attributes_to_set.merge!(attributes)
        end

        def add_value(name, value)
          @attributes_to_add[name] = value
        end

        def delete_value(name, value)
          @attributes_to_delete[name] = value
        end

        def remove_attributes(names)
          @attributes_to_remove.concat(names)
        end

        def request
          key = { @model_class.hash_key => @hash_key }
          key[@model_class.range_key] = @range_key if @model_class.range_key?

          # Build UpdateExpression and keep names and values placeholders mapping
          # in ExpressionAttributeNames and ExpressionAttributeValues.
          update_expression_statements = []
          expression_attribute_names = {}
          expression_attribute_values = {}
          name_placeholder = '#_n0'
          value_placeholder = ':_v0'

          unless @attributes_to_set.empty?
            statements = []

            @attributes_to_set.each do |name, value|
              statements << "#{name_placeholder} = #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "SET #{statements.join(', ')}"
          end

          unless @attributes_to_add.empty?
            statements = []

            @attributes_to_add.each do |name, value|
              statements << "#{name_placeholder} #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "ADD #{statements.join(', ')}"
          end

          unless @attributes_to_delete.empty?
            statements = []

            @attributes_to_delete.each do |name, value|
              statements << "#{name_placeholder} #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "DELETE #{statements.join(', ')}"
          end

          unless @attributes_to_remove.empty?
            name_placeholders = []

            @attributes_to_remove.each do |name|
              name_placeholders << name_placeholder

              expression_attribute_names[name_placeholder] = name

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "REMOVE #{name_placeholders.join(', ')}"
          end

          update_expression = update_expression_statements.join(' ')

          {
            update: {
              key: key,
              table_name: @model_class.table_name,
              update_expression: update_expression,
              expression_attribute_names: expression_attribute_names,
              expression_attribute_values: expression_attribute_values,
              condition_expression: @condition_expression
            }
          }
        end
      end
    end
  end
end
