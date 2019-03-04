# frozen_string_literal: true

require_relative 'middleware/backoff'
require_relative 'middleware/limit'
require_relative 'middleware/start_key'

module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
      class Query
        OPTIONS_KEYS = %i[
          limit hash_key hash_value range_key consistent_read scan_index_forward
          select index_name batch_size exclusive_start_key record_limit scan_limit
        ].freeze

        attr_reader :client, :table, :options, :conditions

        def initialize(client, table, opts = {})
          @client = client
          @table = table

          opts = opts.symbolize_keys
          @options = opts.slice(*OPTIONS_KEYS)
          @conditions = opts.except(*OPTIONS_KEYS)
        end

        def call
          request = build_request

          Enumerator.new do |yielder|
            api_call = -> (request) do
              client.query(request).tap do |response|
                yielder << response
              end
            end

            middlewares = Middleware::Backoff.new(
              Middleware::StartKey.new(
                Middleware::Limit.new(api_call, record_limit: record_limit, scan_limit: scan_limit)
              )
            )

            catch :stop_pagination do
              loop do
                middlewares.call(request)
              end
            end
          end
        end

        private

        def build_request
          request = options.slice(
            :consistent_read,
            :scan_index_forward,
            :select,
            :index_name,
            :exclusive_start_key
          ).compact

          # Deal with various limits and batching
          batch_size = options[:batch_size]
          limit = [record_limit, scan_limit, batch_size].compact.min

          request[:limit]          = limit if limit
          request[:table_name]     = table.name
          request[:key_conditions] = key_conditions
          request[:query_filter]   = query_filter

          request
        end

        def record_limit
          options[:record_limit]
        end

        def scan_limit
          options[:scan_limit]
        end

        def hash_key_name
          (options[:hash_key] || table.hash_key)
        end

        def range_key_name
          (options[:range_key] || table.range_key)
        end

        def key_conditions
          result = {
            hash_key_name => {
              comparison_operator: AwsSdkV3::EQ,
              attribute_value_list: AwsSdkV3.attribute_value_list(AwsSdkV3::EQ, options[:hash_value].freeze)
            }
          }

          conditions.slice(*AwsSdkV3::RANGE_MAP.keys).each do |k, _v|
            op = AwsSdkV3::RANGE_MAP[k]

            result[range_key_name] = {
              comparison_operator: op,
              attribute_value_list: AwsSdkV3.attribute_value_list(op, conditions[k].freeze)
            }
          end

          result
        end

        def query_filter
          conditions.except(*AwsSdkV3::RANGE_MAP.keys).reduce({}) do |result, (attr, cond)|
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
end
