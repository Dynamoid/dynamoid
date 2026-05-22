# frozen_string_literal: true

require_relative 'base'
require_relative 'builders/update_request_builder'

module Dynamoid
  module Transactions
    class Mutation
      # @private
      class Touch < Base
        def initialize(model, *names, time: nil)
          super()

          @model = model
          @names = names
          @time = time
        end

        def on_registration
          if @model.new_record?
            raise Dynamoid::Errors::Error, 'cannot touch on a new or destroyed record object'
          end

          validate_primary_key!

          @model.run_callbacks(:touch) do
            @time_to_assign = @time || DateTime.now.in_time_zone(Time.zone)

            @model.updated_at = @time_to_assign if @model.class.timestamps_enabled?
            @names.each do |name|
              @model.write_attribute(name, @time_to_assign)
            end
          end
        end

        def on_commit
          attribute_names = @names.map(&:to_s)
          attribute_names << 'updated_at' if @model.class.timestamps_enabled?
          @model.clear_attribute_changes(attribute_names)
          @model.run_callbacks(:commit)
        end

        def on_rollback
          @model.run_callbacks(:rollback)
        end

        def aborted?
          false
        end

        def skipped?
          !@model.class.timestamps_enabled? && @names.empty?
        end

        def observable_by_user_result
          @model
        end

        def action_requests
          builder = Builders::UpdateRequestBuilder.new(@model.class)
          builder.hash_key = dump(@model.class.hash_key, @model.hash_key)
          builder.range_key = dump(@model.class.range_key, @model.range_value) if @model.class.range_key?

          # require primary key to exist
          builder.add_expression_attribute_name('#_h', @model.class.hash_key)
          condition_expression = 'attribute_exists(#_h)'

          if @model.class.range_key?
            builder.add_expression_attribute_name('#_r', @model.class.range_key)
            condition_expression += ' AND attribute_exists(#_r)'
          end
          builder.condition_expression = condition_expression

          attributes_to_set = {}
          attributes_to_set[:updated_at] = dump(:updated_at, @model[:updated_at]) if @model.class.timestamps_enabled?

          @names.each do |name|
            attributes_to_set[name] = dump(name, @model[name])
          end

          builder.set_attributes(attributes_to_set)
          [builder.request]
        end

        private

        def validate_primary_key!
          raise Dynamoid::Errors::MissingHashKey if @model.hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model.class.range_key? && @model.range_value.nil?
        end

        def dump(name, value)
          options = @model.class.attributes[name]
          Dumping.dump_field(value, options)
        end
      end
    end
  end
end
