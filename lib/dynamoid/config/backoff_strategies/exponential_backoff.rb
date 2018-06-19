# frozen_string_literal: true

module Dynamoid
  module Config
    module BackoffStrategies
      # Truncated binary exponential backoff algorithm
      # See https://en.wikipedia.org/wiki/Exponential_backoff
      class ExponentialBackoff
        def self.call(opts = {})
          opts = { base_backoff: 0.5, ceiling: 3 }.merge(opts)
          base_backoff = opts[:base_backoff]
          ceiling = opts[:ceiling]

          times = 1

          lambda do
            power = [times - 1, ceiling - 1].min
            backoff = base_backoff * (2**power)
            sleep backoff

            times += 1
          end
        end
      end
    end
  end
end
