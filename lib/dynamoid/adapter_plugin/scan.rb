module Dynamoid
  module AdapterPlugin
    class Scan
      def call(client, table, scan_hash = {}, select_opts = {})
        request = { table_name: table.name }
        request[:consistent_read] = true if select_opts.delete(:consistent_read)

        # Deal with various limits and batching
        record_limit = select_opts.delete(:record_limit)
        scan_limit = select_opts.delete(:scan_limit)
        batch_size = select_opts.delete(:batch_size)
        exclusive_start_key = select_opts.delete(:exclusive_start_key)
        request_limit = [record_limit, scan_limit, batch_size].compact.min
        request[:limit] = request_limit if request_limit
        request[:exclusive_start_key] = exclusive_start_key if exclusive_start_key

        if scan_hash.present?
          request[:scan_filter] = scan_hash.reduce({}) do |memo, (attr, cond)|
            memo.merge(attr.to_s => {
            comparison_operator: AwsSdkV3::FIELD_MAP[cond.keys[0]],
            attribute_value_list: AwsSdkV3.attribute_value_list(AwsSdkV3::FIELD_MAP[cond.keys[0]], cond.values[0].freeze)
          })
          end
        end

        Enumerator.new do |y|
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

            results = client.scan(request)
            y << results

            record_count += results.count
            break if record_limit && record_count >= record_limit

            scan_count += results.scanned_count
            break if scan_limit && scan_count >= scan_limit

            # Keep pulling if we haven't finished paging in all data
            if (lk = results[:last_evaluated_key])
              request[:exclusive_start_key] = lk
            else
              break
            end

            backoff.call if backoff
          end
        end
      end
    end
  end
end
