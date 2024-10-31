# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class Destroy
      def initialize(model)
        @model = model
        @model_class = model.class
        @aborted = false
      end

      def on_registration
        validate_model!

        @aborted = true
        @model.run_callbacks(:destroy) do
          @aborted = false
          true
        end
      end

      def on_completing
        return if @aborted
        @model.destroyed = true
      end

      def aborted?
        @aborted
      end

      def skip?
        false
      end

      def observable_by_user_result
        @model
      end

      def action_request
        key = { @model_class.hash_key => @model.hash_key }
        key[@model_class.range_key] = @model.range_value if @model_class.range_key?
        # force fast fail i.e. won't retry if record is missing
        condition_expression = "attribute_exists(#{@model_class.hash_key})"
        condition_expression += " and attribute_exists(#{@model_class.range_key})" if @model_class.range_key? # needed?
        result = {
          delete: {
            key: key,
            table_name: @model_class.table_name
          }
        }
        result[:delete][:condition_expression] = condition_expression
        result
      end

      private

      def validate_model!
        raise Dynamoid::Errors::MissingHashKey if @model.hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
      end
    end
  end
end
