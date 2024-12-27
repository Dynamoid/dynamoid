# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  class TransactionWrite
    class Create < Base
      def initialize(model_class, attributes = {}, **options, &block)
        @model = model_class.new(attributes)

        if block
          yield(@model)
        end

        @save_action = Save.new(@model, **options)
      end

      def on_registration
        @save_action.on_registration
      end

      def on_commit
        @save_action.on_commit
      end

      def on_rollback
        @save_action.on_rollback
      end

      def aborted?
        @save_action.aborted?
      end

      def skipped?
        false
      end

      def observable_by_user_result
        @model
      end

      def action_request
        @save_action.action_request
      end
    end
  end
end
