# frozen_string_literal: true

module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
      module Middleware
        class Limit
          def initialize(next_chain, record_limit: nil, scan_limit: nil)
            @next_chain = next_chain

            @record_limit = record_limit
            @scan_limit = scan_limit

            @record_count = 0
            @scan_count = 0
          end

          def call(request)
            # Adjust the limit down if the remaining record and/or scan limit are
            # lower to obey limits. We can assume the difference won't be
            # negative due to break statements below but choose smaller limit
            # which is why we have 2 separate if statements.
            # NOTE: Adjusting based on record_limit can cause many HTTP requests
            # being made. We may want to change this behavior, but it affects
            # filtering on data with potentially large gaps.
            # Example:
            #    User.where('created_at.gte' => 1.day.ago).record_limit(1000)
            #    Records 1-999 User's that fit criteria
            #    Records 1000-2000 Users's that do not fit criteria
            #    Record 2001 fits criteria
            # The underlying implementation will have 1 page for records 1-999
            # then will request with limit 1 for records 1000-2000 (making 1000
            # requests of limit 1) until hit record 2001.
            if request[:limit] && @record_limit && @record_limit - @record_count < request[:limit]
              request[:limit] = @record_limit - @record_count
            end
            if request[:limit] && @scan_limit && @scan_limit - @scan_count < request[:limit]
              request[:limit] = @scan_limit - @scan_count
            end

            response = @next_chain.call(request)

            @record_count += response.count
            throw :stop_pagination if @record_limit && @record_count >= @record_limit

            @scan_count += response.scanned_count
            throw :stop_pagination if @scan_limit && @scan_count >= @scan_limit

            response
          end
        end
      end
    end
  end
end
