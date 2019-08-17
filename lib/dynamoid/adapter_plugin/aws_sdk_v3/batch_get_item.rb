module Dynamoid
  module AdapterPlugin
    class AwsSdkV3

      class BatchGetItem
        attr_reader :client, :table_ids, :options

        def initialize(client, table_ids, options = {})
          @client = client
          @table_ids = table_ids
          @options = options
        end

        def call
          request_items = Hash.new { |h, k| h[k] = [] }
          return request_items if table_ids.all? { |_k, v| v.blank? }

          ret = Hash.new([].freeze) # Default for tables where no rows are returned

          table_ids.each do |t, ids|
            next if ids.blank?

            ids = Array(ids).dup
            tbl = t # <====
            t = tbl.name # <====
            hk  = tbl.hash_key.to_s
            rng = tbl.range_key.to_s

            while ids.present?
              batch = ids.shift(Dynamoid::Config.batch_size)

              request_items = Hash.new { |h, k| h[k] = [] }

              keys = if rng.present?
                       Array(batch).map do |h, r|
                         { hk => h, rng => r }
                       end
                     else
                       Array(batch).map do |id|
                         { hk => id }
                       end
                     end

              request_items[t] = {
                keys: keys,
                consistent_read: options[:consistent_read]
              }

              results = client.batch_get_item(
                request_items: request_items
              )

              if block_given?
                batch_results = Hash.new([].freeze)

                results.data[:responses].each do |table, rows|
                  batch_results[table] += rows.collect { |r| result_item_to_hash(r) }
                end

                yield(batch_results, results.unprocessed_keys.present?)
              else
                results.data[:responses].each do |table, rows|
                  ret[table] += rows.collect { |r| result_item_to_hash(r) }
                end
              end

              if results.unprocessed_keys.present?
                ids += results.unprocessed_keys[t].keys.map { |h| h[hk] }
              end
            end
          end

          ret unless block_given?
        end

        private

        def result_item_to_hash(item)
          item.symbolize_keys
        end
      end
    end
  end
end
