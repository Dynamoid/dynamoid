# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  class TransactionWrite
    class DeleteWithInstance < Base
      def initialize(model)
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
        key = { @model_class.hash_key => @model.hash_key }

        if @model_class.range_key?
          key[@model_class.range_key] = @model.range_value
        end

        {
          delete: {
            key: key,
            table_name: @model_class.table_name
          }
        }
      end

      private

      def validate_model!
        raise Dynamoid::Errors::MissingHashKey if @model.hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @model.range_value.nil?
      end
    end
  end
end
