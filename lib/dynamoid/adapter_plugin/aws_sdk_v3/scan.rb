# frozen_string_literal: true

require_relative 'middleware/backoff'
require_relative 'middleware/limit'
require_relative 'middleware/start_key'

module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
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
            api_call = lambda do |req|
              client.scan(req).tap do |response|
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
            :exclusive_start_key,
            :select
          ).compact

          # Deal with various limits and batching
          batch_size = options[:batch_size]
          limit = [record_limit, scan_limit, batch_size].compact.min

          request[:limit]             = limit if limit
          request[:table_name]        = table.name
          request[:scan_filter]       = scan_filter
          request[:attributes_to_get] = attributes_to_get

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
            # nil means operator doesn't require attribute value list
            conditions.delete(:attribute_value_list) if conditions[:attribute_value_list].nil?
            result[attr] = condition
            result
          end
        end

        def attributes_to_get
          return if options[:project].nil?

          options[:project].map(&:to_s)
        end
      end
    end
  end
end
