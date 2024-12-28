# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class Base
      # Callback called at "initialization" or "registration" an action
      # before changes are persisted. It's a proper place to validate
      # a model or run callbacks
      def on_registration
        raise 'Not implemented'
      end

      # Callback called after changes are persisted.
      # It's a proper place to mark changes in a model as applied.
      def on_commit
        raise 'Not implemented'
      end

      # Callback called when a transaction is rolled back.
      # It's a proper place to undo changes made in after_... callbacks.
      def on_rollback
        raise 'Not implemented'
      end

      # Whether some callback aborted or canceled an action
      def aborted?
        raise 'Not implemented'
      end

      # Whether there are changes to persist, e.g. updating a model with no
      # attribute changed is skipped.
      def skipped?
        raise 'Not implemented'
      end

      # Value returned to a user as an action result
      def observable_by_user_result
        raise 'Not implemented'
      end

      # Coresponding part of a final request body
      def action_request
        raise 'Not implemented'
      end
    end
  end
end
