module Dynamoid
  module AdapterPlugin
    class Query
      def call(client, table, opts = {})
        hk    = (opts[:hash_key].present? ? opts.delete(:hash_key) : table.hash_key).to_s
        rng   = (opts[:range_key].present? ? opts.delete(:range_key) : table.range_key).to_s
        q     = opts.slice(
          :consistent_read,
          :scan_index_forward,
          :select,
          :index_name
        )

        opts.delete(:consistent_read)
        opts.delete(:scan_index_forward)
        opts.delete(:select)
        opts.delete(:index_name)

        # Deal with various limits and batching
        record_limit = opts.delete(:record_limit)
        scan_limit = opts.delete(:scan_limit)
        batch_size = opts.delete(:batch_size)
        exclusive_start_key = opts.delete(:exclusive_start_key)
        limit = [record_limit, scan_limit, batch_size].compact.min

        key_conditions = {
          hk => {
            comparison_operator: AwsSdkV3::EQ,
            attribute_value_list: AwsSdkV3.attribute_value_list(AwsSdkV3::EQ, opts.delete(:hash_value).freeze)
          }
        }

        opts.each_pair do |k, _v|
          next unless (op = AwsSdkV3::RANGE_MAP[k])
          key_conditions[rng] = {
            comparison_operator: op,
            attribute_value_list: AwsSdkV3.attribute_value_list(op, opts.delete(k).freeze)
          }
        end

        query_filter = {}
        opts.reject { |k, _| k.in? AwsSdkV3::RANGE_MAP.keys }.each do |attr, hash|
          query_filter[attr] = {
            comparison_operator: AwsSdkV3::FIELD_MAP[hash.keys[0]],
            attribute_value_list: AwsSdkV3.attribute_value_list(AwsSdkV3::FIELD_MAP[hash.keys[0]], hash.values[0].freeze)
          }
        end

        q[:limit] = limit if limit
        q[:exclusive_start_key] = exclusive_start_key if exclusive_start_key
        q[:table_name]     = table.name
        q[:key_conditions] = key_conditions
        q[:query_filter]   = query_filter

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
            if q[:limit] && record_limit && record_limit - record_count < q[:limit]
              q[:limit] = record_limit - record_count
            end
            if q[:limit] && scan_limit && scan_limit - scan_count < q[:limit]
              q[:limit] = scan_limit - scan_count
            end

            results = client.query(q)
            y << results

            record_count += results.count
            break if record_limit && record_count >= record_limit

            scan_count += results.scanned_count
            break if scan_limit && scan_count >= scan_limit

            if (lk = results.last_evaluated_key)
              q[:exclusive_start_key] = lk
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
