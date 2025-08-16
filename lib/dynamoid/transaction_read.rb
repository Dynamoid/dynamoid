# frozen_string_literal: true

require 'dynamoid/transaction_read/find'

module Dynamoid
  # The class +TransactionRead+ provides means to perform multiple reading
  # operations in transaction, that is atomically, so that either all of them
  # succeed, or all of them fail.
  #
  # The reading methods are supposed to be as close as possible to their
  # non-transactional counterparts:
  #
  #   user_id = params[:user_id]
  #   payment = params[:payment_id]
  #
  #   models = Dynamoid::TransactionRead.execute do |t|
  #     t.find User, user_id
  #     t.find Payment, payment_id
  #   end
  #
  # The only difference is that the methods are called on a transaction
  # instance and a model or a model class should be specified. So +User.find+
  # becomes +t.find(user_id)+ and +Payment.find(payment_id)+ becomes +t.find
  # Payment, payment_id+.
  #
  # A transaction can be used without a block. This way a transaction instance
  # should be instantiated and committed manually with +#commit+ method:
  #
  #   t = Dynamoid::TransactionRead.new
  #
  #   t.find user_id
  #   t.find payment_id
  #
  #   models = t.commit
  #
  #
  # ### DynamoDB's transactions
  #
  # The main difference between DynamoDB transactions and a common interface is
  # that DynamoDB's transactions are executed in batch. So in Dynamoid no
  # data actually loaded when some transactional method (e.g+ `#find+) is
  # called. All the changes are loaded at the end.
  #
  # A +TransactGetItems+ DynamoDB operation is used (see
  # [documentation](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_TransactGetItems.html)
  # for details).
  class TransactionRead
    def self.execute
      transaction = new

      begin
        yield transaction
        transaction.commit
      end
    end

    def initialize
      @actions = []
    end

    # Load all the models.
    #
    #   transaction = Dynamoid::TransactionRead.new
    #   # ...
    #   transaction.commit
    def commit
      return [] if @actions.empty?

      # some actions may produce multiple requests
      action_request_groups = @actions.map(&:action_request).map do |action_request|
        action_request.is_a?(Array) ? action_request : [action_request]
      end
      action_requests = action_request_groups.flatten(1)

      return [] if action_requests.empty?

      response = Dynamoid.adapter.transact_read_items(action_requests)

      responses = response.responses.dup
      @actions.zip(action_request_groups).map do |action, action_requests|
        action_responses = responses.shift(action_requests.size)
        action.process_responses(action_responses)
      end.flatten
    end

    # Find one or many objects, specified by one id or an array of ids.
    #
    # By default it raises +RecordNotFound+ exception if at least one model
    # isn't found. This behavior can be changed with +raise_error+ option. If
    # specified +raise_error: false+ option then +find+ will not raise the
    # exception.
    #
    # When a document schema includes range key it should always be specified
    # in +find+ method call. In case it's missing +MissingRangeKey+ exception
    # will be raised.
    #
    # Please note that there are the following differences between
    # transactional and non-transactional +find+:
    # - transactional +find+ preserves order of models in result when given multiple ids
    # - transactional +find+ doesn't return results immediately, a single
    #   collection with results of all the +find+ calls is returned instead
    # - +:consistent_read+ option isn't supported
    # - transactional +find+ is subject to limitations of the
    #   [TransactGetItems](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_TransactGetItems.html)
    #   DynamoDB operation, e.g. the whole read transaction can load only up to 100 models.
    #
    # @param [Object|Array] ids a single primary key or an array of primary keys
    # @param [Hash] options optional parameters of the operation
    # @option options [Object] :range_key sort key of a model; required when a single partition key is given and a sort key is declared for a model
    # @option options [true|false] :raise_error whether to raise a +RecordNotFound+ exception; specify explicitly +raise_error: false+ to suppress the exception; default is +true+
    # @return [nil]
    #
    # @example Find by partition key
    #   Dynamoid::TransactionRead.execute do |t|
    #     t.find Document, 101
    #   end
    #
    # @example Find by partition key and sort key
    #   Dynamoid::TransactionRead.execute do |t|
    #     t.find Document, 101, range_key: 'archived'
    #   end
    #
    # @example Find several documents by partition key
    #   Dynamoid::TransactionRead.execute do |t|
    #     t.find Document, 101, 102, 103
    #     t.find Document, [101, 102, 103]
    #   end
    #
    # @example Find several documents by partition key and sort key
    #   Dynamoid::TransactionRead.execute do |t|
    #     t.find Document, [[101, 'archived'], [102, 'new'], [103, 'deleted']]
    #   end
    def find(model_class, *ids, **options)
      action = Dynamoid::TransactionRead::Find.new(model_class, *ids, **options)
      register_action action
    end

    private

    def register_action(action)
      @actions << action
      action.on_registration
      action.observable_by_user_result
    end
  end
end
