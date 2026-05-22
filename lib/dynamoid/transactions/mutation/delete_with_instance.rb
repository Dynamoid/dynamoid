# frozen_string_literal: true

require_relative 'base'
require_relative 'delete_request_builder'

module Dynamoid
  module Transactions
    class Mutation
      class DeleteWithInstance < Base
        def initialize(model)
          super()

          @model = model
          @model_class = model.class
        end

        def on_registration
          validate_model!
        end

        def on_commit
          @model.destroyed = true
          @model.run_callbacks(:commit)
        end

        def on_rollback
          @model.run_callbacks(:rollback)
        end

        def aborted?
          false
        end

        def skipped?
          false
        end

        def observable_by_user_result
          @model
        end

        def action_requests
          builder = DeleteRequestBuilder.new(@model_class)
          builder.hash_key = dump_attribute(@model_class.hash_key, @model.hash_key)
          builder.range_key = dump_attribute(@model_class.range_key, @model.range_value) if @model_class.range_key?

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

          [builder.request]
        end

        private

        def validate_model!
          raise Dynamoid::Errors::MissingHashKey if @model.hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
        end

        def dump_attribute(name, value)
          options = @model_class.attributes[name]
          Dumping.dump_field(value, options)
        end
      end
    end
  end
end
