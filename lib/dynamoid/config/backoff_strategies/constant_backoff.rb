module Dynamoid
  module Config
    module BackoffStrategies
      class ConstantBackoff
        def self.call(n)
          -> { sleep n }
        end
      end
    end
  end
end
