# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  class TransactionWrite
    class Save < Base
      def initialize(model, **options)
        super()

        @model = model
        @model_class = model.class
        @options = options

        @aborted = false
        @was_new_record = model.new_record?
        @valid = nil
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
        @model.persisted? && !@model.changed?
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

      private

      def validate_model!
        raise Dynamoid::Errors::MissingHashKey if !@was_new_record && @model.hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
      end

      def action_request_to_create
        touch_model_timestamps(skip_created_at: false)

        attributes_dumped = Dynamoid::Dumping.dump_attributes(@model.attributes, @model_class.attributes)
        attributes_dumped = sanitize_item(attributes_dumped)

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
        key = { @model_class.hash_key => dump_attribute(@model_class.hash_key, @model.hash_key) }
        key[@model_class.range_key] = dump_attribute(@model_class.range_key, @model.range_value) if @model_class.range_key?

        # Build UpdateExpression and keep names and values placeholders mapping
        # in ExpressionAttributeNames and ExpressionAttributeValues.
        set_expression_statements = []
        remove_expression_statements = []
        expression_attribute_names = {}
        expression_attribute_values = {}

        changes_dumped.each_with_index do |(name, value), i|
          name_placeholder = "#_n#{i}"
          value_placeholder = ":_s#{i}"

          if value || Dynamoid.config.store_attribute_with_nil_value
            set_expression_statements << "#{name_placeholder} = #{value_placeholder}"
            expression_attribute_values[value_placeholder] = value
          else
            remove_expression_statements << name_placeholder
          end
          expression_attribute_names[name_placeholder] = name
        end

        update_expression = ''
        update_expression += "SET #{set_expression_statements.join(', ')}" if set_expression_statements.any?
        update_expression += " REMOVE #{remove_expression_statements.join(', ')}" if remove_expression_statements.any?

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

      def dump_attribute(name, value)
        options = @model_class.attributes[name]
        Dumping.dump_field(value, options)
      end
    end
  end
end
