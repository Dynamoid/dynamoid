# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  class TransactionWrite
    class Destroy < Base
      def initialize(model, **options)
        super()

        @model = model
        @options = options
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

        if @aborted && @options[:raise_error]
          raise Dynamoid::Errors::RecordNotDestroyed, @model
        end
      end

      def on_commit
        return if @aborted

        @model.destroyed = true
        @model.run_callbacks(:commit)
      end

      def on_rollback
        @model.run_callbacks(:rollback)
      end

      def aborted?
        @aborted
      end

      def skipped?
        false
      end

      def observable_by_user_result
        return false if @aborted

        @model
      end

      def action_request
        key = { @model_class.hash_key => dump_attribute(@model_class.hash_key, @model.hash_key) }

        if @model_class.range_key?
          key[@model_class.range_key] = dump_attribute(@model_class.range_key, @model.range_value)
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

      def dump_attribute(name, value)
        options = @model_class.attributes[name]
        Dumping.dump_field(value, options)
      end
    end
  end
end
