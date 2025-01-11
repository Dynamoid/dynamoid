# frozen_string_literal: true

require_relative 'middleware/backoff'
require_relative 'middleware/limit'
require_relative 'middleware/start_key'
require_relative 'filter_expression_convertor'
require_relative 'projection_expression_convertor'

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      class Scan
        attr_reader :client, :table, :conditions, :options

        def initialize(client, table, conditions = [], options = {})
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
          # expressions
          name_placeholder = +'#_a0'
          value_placeholder = +':_a0'

          name_placeholder_sequence = -> { name_placeholder.next!.dup }
          value_placeholder_sequence = -> { value_placeholder.next!.dup }

          name_placeholders = {}
          value_placeholders = {}

          # Deal with various limits and batching
          batch_size = options[:batch_size]
          limit = [record_limit, scan_limit, batch_size].compact.min

          # filter expression
          convertor = FilterExpressionConvertor.new(conditions, name_placeholders, value_placeholders, name_placeholder_sequence, value_placeholder_sequence)
          filter_expression = convertor.expression
          value_placeholders = convertor.value_placeholders
          name_placeholders = convertor.name_placeholders

          # projection expression
          convertor = ProjectionExpressionConvertor.new(options[:project], name_placeholders, name_placeholder_sequence)
          projection_expression = convertor.expression
          name_placeholders = convertor.name_placeholders

          request = options.slice(
            :consistent_read,
            :exclusive_start_key,
            :select,
            :index_name
          ).compact

          request[:table_name]                  = table.name
          request[:limit]                       = limit                 if limit
          request[:filter_expression]           = filter_expression     if filter_expression.present?
          request[:expression_attribute_values] = value_placeholders    if value_placeholders.present?
          request[:expression_attribute_names]  = name_placeholders     if name_placeholders.present?
          request[:projection_expression]       = projection_expression if projection_expression.present?

          request
        end

        def record_limit
          options[:record_limit]
        end

        def scan_limit
          options[:scan_limit]
        end
      end
    end
  end
end
