# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  class TransactionWrite
    class Save < Base
      def initialize(model, **options, &block)
        super()

        @model = model
        @model_class = model.class
        @options = options

        @aborted = false
        @was_new_record = model.new_record?
        @valid = nil

        @additions = {}
        @deletions = {}
        @removals = []

        yield(self) if block_given?
      end

      def on_registration
        validate_model!

        if @options[:validate] != false && !(@valid = @model.valid?)
          if @options[:raise_error]
            raise Dynamoid::Errors::DocumentNotValid, @model
          else
            @aborted = true
            return
          end
        end

        @aborted = true
        callback_name = @was_new_record ? :create : :update

        @model.run_callbacks(:save) do
          @model.run_callbacks(callback_name) do
            @model.run_callbacks(:validate) do
              @aborted = false
              true
            end
          end
        end

        if @aborted && @options[:raise_error]
          raise Dynamoid::Errors::RecordNotSaved, @model
        end

        if @was_new_record && @model.hash_key.nil?
          @model.hash_key = SecureRandom.uuid
        end
      end

      def on_commit
        return if @aborted

        @model.changes_applied

        if @was_new_record
          @model.new_record = false
        end

        @model.run_callbacks(:commit)
      end

      def on_rollback
        @model.run_callbacks(:rollback)
      end

      def aborted?
        @aborted
      end

      def skipped?
        @model.persisted? && !@model.changed? && @additions.blank? && @deletions.blank? && @removals.blank?
      end

      def observable_by_user_result
        !@aborted
      end

      def action_request
        if @was_new_record
          action_request_to_create
        else
          action_request_to_update
        end
      end

      # sets a value in the attributes
      def set(attributes)
        @model.assign_attributes(attributes)
      end

      # adds to array of fields for use in REMOVE update expression
      def remove(field)
        @removals << field
      end

      # increments a number or adds to a set, starts at 0 or [] if it doesn't yet exist
      def add(values)
        @additions.merge!(values)
      end

      # deletes a value or values from a set type or simply sets a field to nil
      def delete(field_or_values)
        if field_or_values.is_a?(Hash)
          @deletions.merge!(field_or_values)
        else
          remove(field_or_values)
        end
      end

      private

      def validate_model!
        raise Dynamoid::Errors::MissingHashKey if !@was_new_record && @model.hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
      end

      def action_request_to_create
        touch_model_timestamps(skip_created_at: false)

        attributes_dumped = Dynamoid::Dumping.dump_attributes(@model.attributes, @model_class.attributes)

        # require primary key not to exist yet
        condition = "attribute_not_exists(#{@model_class.hash_key})"
        if @model_class.range_key?
          condition += " AND attribute_not_exists(#{@model_class.range_key})"
        end

        {
          put: {
            item: attributes_dumped,
            table_name: @model_class.table_name,
            condition_expression: condition
          }
        }
      end

      def action_request_to_update
        touch_model_timestamps(skip_created_at: true)

        # changed attributes to persist
        changes = @model.attributes.slice(*@model.changed.map(&:to_sym))
        changes_dumped = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

        # primary key to look up an item to update
        key = { @model_class.hash_key => @model.hash_key }
        key[@model_class.range_key] = @model.range_value if @model_class.range_key?

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

        update_expression = set_additions(expression_attribute_values, update_expression)
        update_expression = set_deletions(expression_attribute_values, update_expression)
        expression_attribute_names, update_expression = set_removals(expression_attribute_names, update_expression)

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

      def touch_model_timestamps(skip_created_at:)
        return unless @model_class.timestamps_enabled?

        timestamp = DateTime.now.in_time_zone(Time.zone)
        @model.updated_at = timestamp unless @options[:touch] == false && !@was_new_record
        @model.created_at ||= timestamp unless skip_created_at
      end

      # adds all of the ADD statements to the update_expression and returns it
      def set_additions(expression_attribute_values, update_expression)
        return update_expression unless @additions.present?

        # ADD statements can be used to increment a counter:
        # txn.update!(UserCount, "UserCount#Red", {}, options: {add: {record_count: 1}})
        add_keys = @additions.keys
        update_expression += " ADD #{add_keys.each_with_index.map { |k, i| "#{k} :_a#{i}" }.join(', ')}"
        # convert any enumerables into sets
        add_values = @additions.transform_values do |v|
          if !v.is_a?(Set) && v.is_a?(Enumerable)
            Set.new(v)
          else
            v
          end
        end
        add_keys.each_with_index { |k, i| expression_attribute_values[":_a#{i}"] = add_values[k] }
        update_expression
      end

      # adds all of the DELETE statements to the update_expression and returns it
      def set_deletions(expression_attribute_values, update_expression)
        return update_expression unless @deletions.present?

        delete_keys = @deletions.keys
        update_expression += " DELETE #{delete_keys.each_with_index.map { |k, i| "#{k} :_d#{i}" }.join(', ')}"
        # values must be sets
        delete_values = @deletions.transform_values do |v|
          if v.is_a?(Set)
            v
          else
            Set.new(v.is_a?(Enumerable) ? v : [v])
          end
        end
        delete_keys.each_with_index { |k, i| expression_attribute_values[":_d#{i}"] = delete_values[k] }
        update_expression
      end

      # adds all of the removals as a REMOVE clause
      def set_removals(expression_attribute_names, update_expression)
        return expression_attribute_names, update_expression unless @removals.present?

        update_expression += " REMOVE #{@removals.each_with_index.map { |_k, i| "#_r#{i}" }.join(', ')}"
        expression_attribute_names = expression_attribute_names.merge(
          @removals.each_with_index.map { |k, i| ["#_r#{i}", k.to_s] }.to_h
        )
        [expression_attribute_names, update_expression]
      end

    end
  end
end
