# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      # Documentation
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#batch_get_item-instance_method
      class BatchGetItem
        attr_reader :client, :tables_with_ids, :options

        def initialize(client, tables_with_ids, options = {})
          @client = client
          @tables_with_ids = tables_with_ids
          @options = options
        end

        def call
          results = {}

          tables_with_ids.each do |table, ids|
            if ids.blank?
              results[table.name] = []
              next
            end

            ids = Array(ids).dup

            while ids.present?
              batch = ids.shift(Dynamoid::Config.batch_size)
              request = build_request(table, batch)
              api_response = client.batch_get_item(request)
              response = Response.new(api_response)

              if block_given?
                # return batch items as a result
                batch_results = Hash.new([].freeze)
                batch_results.update(response.items_grouped_by_table)

                yield(batch_results, response.successful_partially?)
              else
                # collect all the batches to return at the end
                results.update(response.items_grouped_by_table) { |_, its1, its2| its1 + its2 }
              end

              if response.successful_partially?
                ids += response.unprocessed_ids(table)
              end
            end
          end

          results unless block_given?
        end

        private

        def build_request(table, ids)
          ids = Array(ids)

          keys = if table.range_key.nil?
                   ids.map { |hk| { table.hash_key => hk } }
                 else
                   ids.map { |hk, rk| { table.hash_key => hk, table.range_key => rk } }
                 end

          {
            request_items: {
              table.name => {
                keys: keys,
                consistent_read: options[:consistent_read]
              }
            }
          }
        end

        # Helper class to work with response
        class Response
          def initialize(api_response)
            @api_response = api_response
          end

          def successful_partially?
            @api_response.unprocessed_keys.present?
          end

          def unprocessed_ids(table)
            # unprocessed_keys Hash contains as values instances of
            # Aws::DynamoDB::Types::KeysAndAttributes
            @api_response.unprocessed_keys[table.name].keys.map do |h|
              # If a table has a composite key then we need to return an array
              # of [hash_key, composite_key]. Otherwise just return hash key's
              # value.
              if table.range_key.nil?
                h[table.hash_key.to_s]
              else
                [h[table.hash_key.to_s], h[table.range_key.to_s]]
              end
            end
          end

          def items_grouped_by_table
            # data[:responses] is a Hash[table_name -> items]
            @api_response.data[:responses].transform_values do |items|
              items.map(&method(:item_to_hash))
            end
          end

          private

          def item_to_hash(item)
            item.symbolize_keys
          end
        end
      end
    end
  end
end
