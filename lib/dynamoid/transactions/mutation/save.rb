# frozen_string_literal: true

require_relative 'base'
require_relative 'update_request_builder'

module Dynamoid
  module Transactions
    class Mutation
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
                validate_primary_key!

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

          if @model.class.attributes[:lock_version]
            if @model.lock_version.nil? && @model.new_record?
              @model.lock_version = 1
            end

            if @model.lock_version && !@model.changes[:lock_version]
              @model.lock_version += 1
            end
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

        def validate_primary_key!
          raise Dynamoid::Errors::MissingHashKey if !@was_new_record && @model.hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
        end

        def action_request_to_create
          touch_model_timestamps(skip_created_at: false)

          attributes_dumped = Dynamoid::Dumping.dump_attributes(@model.attributes, @model_class.attributes)
          attributes_dumped = sanitize_item(attributes_dumped)

          # require primary key not to exist yet
          expression_attribute_names = { '#_h' => @model_class.hash_key }
          condition = 'attribute_not_exists(#_h)'

          if @model_class.range_key?
            expression_attribute_names['#_r'] = @model_class.range_key
            condition += ' AND attribute_not_exists(#_r)'
          end

          {
            put: {
              item: attributes_dumped,
              table_name: @model_class.table_name,
              condition_expression: condition,
              expression_attribute_names: expression_attribute_names
            }
          }
        end

        def action_request_to_update
          touch_model_timestamps(skip_created_at: true)

          # changed attributes to persist
          changes = @model.attributes.slice(*@model.changed.map(&:to_sym))
          changes_dumped = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

          builder = UpdateRequestBuilder.new(@model_class)
          builder.hash_key = dump_attribute(@model_class.hash_key, @model.hash_key)
          builder.range_key = dump_attribute(@model_class.range_key, @model.range_value) if @model_class.range_key?

          attributes_to_set = {}
          attributes_to_remove = []

          changes_dumped.each do |name, value|
            if value || Dynamoid.config.store_attribute_with_nil_value
              attributes_to_set[name] = value
            else
              attributes_to_remove << name
            end
          end

          builder.set_attributes(attributes_to_set)
          builder.remove_attributes(attributes_to_remove)

          if @model_class.attributes[:lock_version]
            lock_version = if @model.changes[:lock_version].nil?
                             @model.lock_version
                           else
                             @model.changes[:lock_version][0]
                           end

            # skip concurrency control when lock_version is nil
            if lock_version
              builder.add_expression_attribute_name('#_lock_version', 'lock_version')
              builder.add_expression_attribute_value(':lock_version_value', lock_version)
              builder.condition_expression = '#_lock_version = :lock_version_value'
            end
          end

          builder.request
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
end
