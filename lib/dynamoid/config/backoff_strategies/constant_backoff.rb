# frozen_string_literal: true

module Dynamoid
  module Config
    module BackoffStrategies
      class ConstantBackoff
        def self.call(sec = 1)
          -> { sleep sec }
        end
      end
    end
  end
end
