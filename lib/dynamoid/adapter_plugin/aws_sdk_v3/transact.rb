# frozen_string_literal: true

# Prepare all the actions of the transaction for sending to the AWS SDK.
module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
      class Transact
        attr_reader :client

        def initialize(client)
          @client = client
        end

        # Perform all of the item actions in a single transaction.
        #
        # @param [Array] items of type Dynamoid::Transaction::Action or
        # any other object whose to_h is a transact_item hash
        #
        def transact_write_items(items)
          transact_items = items.map(&:to_h)
          params = {
            transact_items: transact_items,
            return_consumed_capacity: 'TOTAL',
            return_item_collection_metrics: 'SIZE'
          }
          client.transact_write_items(params) # returns this
        end
      end
    end
  end
end
