# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class DeleteWithPrimaryKey
      def initialize(model_class, hash_key, range_key)
        @model_class = model_class
        @hash_key = hash_key
        @range_key = range_key
      end

      def on_registration
        validate_primary_key!
      end

      def on_completing; end

      def aborted?
        false
      end

      def skip?
        false
      end

      def observable_by_user_result
        nil
      end

      def action_request
        key = { @model_class.hash_key => @hash_key }
        key[@model_class.range_key] = @range_key if @model_class.range_key?
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
    end
  end
end
