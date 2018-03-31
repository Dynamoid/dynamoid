module Dynamoid
  module Config
    module BackoffStrategies
      class ConstantBackoff
        def self.call(n = 1)
          -> { sleep n }
        end
      end
    end
  end
end
