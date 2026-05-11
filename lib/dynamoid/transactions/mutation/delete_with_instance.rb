# frozen_string_literal: true

require_relative 'base'

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
        end

        def on_rollback; end

        def aborted?
          false
        end

        def skipped?
          false
        end

        def observable_by_user_result
          @model
        end

        def action_request
          key = { @model_class.hash_key => dump_attribute(@model_class.hash_key, @model.hash_key) }

          if @model_class.range_key?
            key[@model_class.range_key] = dump_attribute(@model_class.range_key, @model.range_value)
          end

          options = {
            key: key,
            table_name: @model_class.table_name
          }

          if @model_class.attributes[:lock_version]
            lock_version = if @model.changes[:lock_version].nil?
                             @model.lock_version
                           else
                             @model.changes[:lock_version][0]
                           end

            options[:condition_expression] = 'lock_version = :lock_version_value'
            options[:expression_attribute_values] = { ':lock_version_value' => lock_version }
          end

          { delete: options }
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
