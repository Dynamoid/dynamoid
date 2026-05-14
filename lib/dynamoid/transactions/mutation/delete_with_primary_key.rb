# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  module Transactions
    class Mutation
      class DeleteWithPrimaryKey < Base
        def initialize(model_class, hash_key, range_key)
          super()

          @model_class = model_class
          @hash_key = hash_key
          @range_key = range_key
        end

        def on_registration
          validate_primary_key!
        end

        def on_commit; end

        def on_rollback; end

        def aborted?
          false
        end

        def skipped?
          false
        end

        def observable_by_user_result
          nil
        end

        def action_request
          key = { @model_class.hash_key => cast_and_dump(@model_class.hash_key, @hash_key) }

          if @model_class.range_key?
            key[@model_class.range_key] = cast_and_dump(@model_class.range_key, @range_key)
          end

          {
            delete: {
              key: key,
              table_name: @model_class.table_name
            }
          }
        end

        private

        def validate_primary_key!
          raise Dynamoid::Errors::MissingHashKey if @hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @range_key.nil?
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
