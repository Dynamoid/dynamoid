module Dynamoid
  module AdapterPlugin
    class Scan
      attr_reader :client, :table, :conditions, :options

      def initialize(client, table, conditions = {}, options = {})
        @client = client
        @table = table
        @conditions = conditions
        @options = options
      end

      def call
        request = build_request

        Enumerator.new do |yielder|
          record_count = 0
          scan_count = 0

          backoff = Dynamoid.config.backoff ? Dynamoid.config.build_backoff : nil

          loop do
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
            if request[:limit] && record_limit && record_limit - record_count < request[:limit]
              request[:limit] = record_limit - record_count
            end
            if request[:limit] && scan_limit && scan_limit - scan_count < request[:limit]
              request[:limit] = scan_limit - scan_count
            end

            response = client.scan(request)

            yielder << response

            record_count += response.count
            break if record_limit && record_count >= record_limit

            scan_count += response.scanned_count
            break if scan_limit && scan_count >= scan_limit

            # Keep pulling if we haven't finished paging in all data
            if response.last_evaluated_key
              request[:exclusive_start_key] = response.last_evaluated_key
            else
              break
            end

            backoff.call if backoff
          end
        end
      end

      private

      def build_request
        request = options.slice(
          :consistent_read,
          :exclusive_start_key,
          :select
        ).compact

        # Deal with various limits and batching
        batch_size = options.delete(:batch_size)
        limit = [record_limit, scan_limit, batch_size].compact.min

        request[:limit]       = limit if limit
        request[:table_name]  = table.name
        request[:scan_filter] = scan_filter

        request
      end

      def record_limit
        options[:record_limit]
      end

      def scan_limit
        options[:scan_limit]
      end

      def scan_filter
        conditions.reduce({}) do |result, (attr, cond)|
          condition = {
            comparison_operator: AwsSdkV3::FIELD_MAP[cond.keys[0]],
            attribute_value_list: AwsSdkV3.attribute_value_list(AwsSdkV3::FIELD_MAP[cond.keys[0]], cond.values[0].freeze)
          }
          result[attr] = condition
          result
        end
      end
    end
  end
end
