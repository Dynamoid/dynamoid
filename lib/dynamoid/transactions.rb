# frozen_string_literal: true

require 'dynamoid/transactions/retrieval'
require 'dynamoid/transactions/mutation'

module Dynamoid
  # The Transactions module provides a way to run blocks of code within a
  # DynamoDB transaction.
  #
  # DynamoDB supports two types of transactions: read-only and write-only.
  # This module provides a unified interface to both.
  #
  # @example Rails-style transaction (defaults to write)
  #   User.transaction do |t|
  #     t.save(user)
  #     t.create(Account, name: 'A')
  #   end
  #
  # @example Explicit write transaction
  #   User.transaction.writing do |t|
  #     t.save(user)
  #     t.create(Account, name: 'A')
  #   end
  #
  # @example Explicit read transaction
  #   users = User.transaction.reading do |t|
  #     t.find(User, '1')
  #     t.find(User, '2')
  #   end
  module Transactions
    extend ActiveSupport::Concern

    # Proxy object to provide .writing and .reading methods on .transaction
    class Proxy
      def writing(&block)
        Mutation.execute(&block)
      end

      def reading(&block)
        Retrieval.execute(&block)
      end
    end

    module ClassMethods
      # Start a transaction.
      #
      # If a block is given, it starts a write transaction.
      #
      # If no block is given, it returns a proxy object that supports
      # .writing and .reading methods.
      #
      # @param block [Proc] optional block to run in a write transaction
      # @return [Proxy|nil|Array<Dynamoid::Document>]
      def transaction(&block)
        if block_given?
          Mutation.execute(&block)
        else
          Proxy.new
        end
      end
    end
  end
end
