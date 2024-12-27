# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class UpdateAttributes
      def initialize(model, attributes, **options)
        @model = model
        @model.assign_attributes(attributes)
        @save_action = Save.new(model, **options)
      end

      def on_registration
        @save_action.on_registration
      end

      def on_completing
        @save_action.on_completing
      end

      def on_failure
        @save_action.on_failure
      end

      def aborted?
        @save_action.aborted?
      end

      def skip?
        @save_action.skip?
      end

      def observable_by_user_result
        @save_action.observable_by_user_result
      end

      def action_request
        @save_action.action_request
      end
    end
  end
end
