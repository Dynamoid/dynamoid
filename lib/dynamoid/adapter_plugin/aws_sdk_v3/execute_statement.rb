# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3
      # Excecute a PartiQL query
      #
      # Documentation:
      # - https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_ExecuteStatement.html
      # - https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#execute_statement-instance_method
      #
      # NOTE: For reads result may be paginated. Only pagination with NextToken
      # is implemented. Currently LastEvaluatedKey in response cannot be fed to
      # ExecuteStatement to get the next page.
      #
      # See also:
      # - https://repost.aws/questions/QUgNPbBYWiRoOlMsJv-XzrWg/how-to-use-last-evaluated-key-in-execute-statement-request
      # - https://stackoverflow.com/questions/71438439/aws-dynamodb-executestatement-pagination
      class ExecuteStatement
        attr_reader :client, :statement, :parameters, :options

        def initialize(client, statement, parameters, options)
          @client = client
          @statement = statement
          @parameters = parameters
          @options = options.symbolize_keys.slice(:consistent_read)
        end

        def call
          request = {
            statement: @statement,
            parameters: @parameters,
            consistent_read: @options[:consistent_read],
          }

          response = client.execute_statement(request)

          unless response.next_token
            return response_to_items(response)
          end

          Enumerator.new do |yielder|
            yielder.yield(response_to_items(response))

            while response.next_token
              request[:next_token] = response.next_token
              response = client.execute_statement(request)
              yielder.yield(response_to_items(response))
            end
          end
        end

        private

        def response_to_items(response)
          response.items.map(&:symbolize_keys)
        end
      end
    end
  end
end
