# frozen_string_literal: true

require_relative 'base'
require_relative 'update_request_builder'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  module Transactions
    class Mutation
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

          builder = UpdateRequestBuilder.new(@model_class)
          builder.hash_key = cast_and_dump(@model_class.hash_key, @hash_key)
          builder.range_key = cast_and_dump(@model_class.range_key, @range_key) if @model_class.range_key?

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

        def cast_and_dump(name, value)
          options = @model_class.attributes[name]
          value_casted = TypeCasting.cast_field(value, options)
          Dumping.dump_field(value_casted, options)
        end
      end
    end
  end
end
