# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      module Middleware
        class StartKey
          def initialize(next_chain)
            @next_chain = next_chain
          end

          def call(request)
            response = @next_chain.call(request)

            if response.last_evaluated_key
              request[:exclusive_start_key] = response.last_evaluated_key
            else
              throw :stop_pagination
            end

            response
          end
        end
      end
    end
  end
end
