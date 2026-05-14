# frozen_string_literal: true

require_relative 'base'
require_relative 'update_request_builder'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  module Transactions
    class Mutation
      class Inc < Base
        def initialize(model_class, hash_key, range_key, counters)
          super()

          @model_class = model_class
          @hash_key = hash_key
          @range_key = range_key
          @counters = counters || {}
          @touch = @counters.delete(:touch)
        end

        def on_registration
          validate_primary_key!
          Dynamoid::Persistence::UpdateValidations.validate_attributes_exist(@model_class, @counters)
        end

        def on_commit; end

        def on_rollback; end

        def aborted?
          false
        end

        def skipped?
          @counters.empty?
        end

        def observable_by_user_result
          nil
        end

        def action_request
          builder = UpdateRequestBuilder.new(@model_class)

          # primary key to look up an item to update
          builder.hash_key = cast_and_dump(@model_class.hash_key, @hash_key)
          builder.range_key = cast_and_dump(@model_class.range_key, @range_key) if @model_class.range_key?

          # require primary key to exist
          builder.add_expression_attribute_name('#_h', @model_class.hash_key)
          condition_expression = 'attribute_exists(#_h)'

          if @model_class.range_key?
            builder.add_expression_attribute_name('#_r', @model_class.range_key)
            condition_expression += ' AND attribute_exists(#_r)'
          end
          builder.condition_expression = condition_expression

          @counters.each do |name, value|
            builder.add_value(name, cast_and_dump(name, value))
          end

          if @touch
            timestamp = DateTime.now.in_time_zone(Time.zone)

            timestamp_attributes_to_touch.each do |name|
              builder.set_attributes(name => dump(name, timestamp))
            end
          end

          builder.request
        end

        private

        def validate_primary_key!
          raise Dynamoid::Errors::MissingHashKey if @hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @range_key.nil?
        end

        def timestamp_attributes_to_touch
          names = []
          names << :updated_at if @model_class.timestamps_enabled?
          names += Array.wrap(@touch) if @touch != true
          names
        end

        def cast_and_dump(name, value)
          options = @model_class.attributes[name]
          value_casted = TypeCasting.cast_field(value, options)
          Dumping.dump_field(value_casted, options)
        end

        def dump(name, value)
          options = @model_class.attributes[name]
          Dumping.dump_field(value, options)
        end
      end
    end
  end
end
