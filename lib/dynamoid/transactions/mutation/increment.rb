# frozen_string_literal: true

require_relative 'base'
require_relative 'inc'

module Dynamoid
  module Transactions
    class Mutation
      # @private
      class Increment < Base
        def initialize(model, attribute, by, touch: nil)
          super()

          @model = model
          @attribute = attribute
          @by = by
          @touch = touch
          @action_requests = [] # will be filled in later with Inc#action_requests
        end

        def on_registration
          @model.run_callbacks(:touch) do
            @model.increment(@attribute, @by)
            change = @model.read_attribute(@attribute) - (@model.send(:attribute_was, @attribute) || 0)

            inc_action = Inc.new(@model.class, @model.hash_key, @model.range_value, { @attribute => change, touch: @touch })
            inc_action.on_registration
            @action_requests = inc_action.action_requests
          end
        end

        def on_commit
          # ignore Inc#on_commit
          @model.clear_attribute_changes(@attribute)
          @model.run_callbacks(:commit)
        end

        def on_rollback
          # ignore Inc#on_rollback
          @model.run_callbacks(:rollback)
        end

        def aborted?
          # ignore Inc#abort?
          false
        end

        def skipped?
          # ignore Inc#skipped?
          @by == 0 # rubocop:disable Style/NumericPredicate
        end

        def observable_by_user_result
          @model
        end

        def action_requests # rubocop:disable Style/TrivialAccessors
          @action_requests
        end
      end
    end
  end
end
