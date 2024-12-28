# frozen_string_literal: true

require_relative 'base'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  class TransactionWrite
    class UpdateAttributes < Base
      def initialize(model, attributes, **options)
        super()

        @model = model
        @model.assign_attributes(attributes)
        @save_action = Save.new(model, **options)
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
        @save_action.skipped?
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
