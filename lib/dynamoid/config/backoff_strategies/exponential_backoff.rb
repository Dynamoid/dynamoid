module Dynamoid
  module Config
    module BackoffStrategies
      # Truncated binary exponential backoff algorithm
      # See https://en.wikipedia.org/wiki/Exponential_backoff
      class ExponentialBackoff
        def self.call(opts)
          base_backoff = opts[:base_backoff]
          ceiling = opts[:ceiling]

          times = 1

          lambda do
            power = times <= ceiling ? times - 1 : ceiling - 1
            backoff = base_backoff * (2 ** power)
            sleep backoff

            times += 1
          end
        end
      end
    end
  end
end
