# frozen_string_literal: true

require 'dynamoid/transaction_write/create'
require 'dynamoid/transaction_write/delete_with_primary_key'
require 'dynamoid/transaction_write/delete_with_instance'
require 'dynamoid/transaction_write/destroy'
require 'dynamoid/transaction_write/save'
require 'dynamoid/transaction_write/update_fields'
require 'dynamoid/transaction_write/update_attributes'
require 'dynamoid/transaction_write/upsert'

module Dynamoid
  # The class +TransactionWrite+ provides means to perform multiple modifying
  # operations in transaction, that is atomically, so that either all of them
  # succeed, or all of them fail.
  #
  # The persisting methods are supposed to be as close as possible to their
  # non-transactional counterparts like +.create+, +#save+ and +#delete+:
  #
  #   user = User.new()
  #   payment = Payment.find(1)
  #
  #   Dynamoid::TransactionWrite.execute do |t|
  #     t.save! user
  #     t.create! Account, name: 'A'
  #     t.delete payment
  #   end
  #
  # The only difference is that the methods are called on a transaction
  # instance and a model or a model class should be specified.
  #
  # So +user.save!+ becomes +t.save!(user)+, +Account.create!(name: 'A')+
  # becomes +t.create!(Account, name: 'A')+, and +payment.delete+ becomes
  # +t.delete(payment)+.
  #
  # A transaction can be used without a block. This way a transaction instance
  # should be instantiated and committed manually with +#commit+ method:
  #
  #   t = Dynamoid::TransactionWrite.new
  #
  #   t.save! user
  #   t.create! Account, name: 'A'
  #   t.delete payment
  #
  #   t.commit
  #
  # Some persisting methods are intentionally not available in a transaction,
  # e.g. +.update+ and +.update!+ that simply call +.find+ and
  # +#update_attributes+ methods. These methods perform multiple operations so
  # cannot be implemented in a transactional atomic way.
  #
  #
  # ### DynamoDB's transactions
  #
  # The main difference between DynamoDB transactions and a common interface is
  # that DynamoDB's transactions are executed in batch. So in Dynamoid no
  # changes are actually persisted when some transactional method (e.g+ `#save+) is
  # called. All the changes are persisted at the end.
  #
  # A +TransactWriteItems+ DynamoDB operation is used (see
  # [documentation](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_TransactWriteItems.html)
  # for details).
  #
  #
  # ### Callbacks
  #
  # The transactional methods support +before_+, +after_+ and +around_+
  # callbacks to the extend the non-transactional methods support them.
  #
  # There is important difference - a transactional method runs callbacks
  # immediately (even +after_+ ones) when it is called before changes are
  # actually persisted. So code in +after_+ callbacks does not see observes
  # them in DynamoDB and so for.
  #
  # When a callback aborts persisting of a model or a model is invalid then
  # transaction is not aborted and may commit successfully.
  #
  #
  # ### Transaction rollback
  #
  # A transaction is rolled back on DynamoDB's side automatically when:
  # - an ongoing operation is in the process of updating the same item.
  # - there is insufficient provisioned capacity for the transaction to be completed.
  # - an item size becomes too large (bigger than 400 KB), a local secondary index (LSI) becomes too large, or a similar validation error occurs because of changes made by the transaction.
  # - the aggregate size of the items in the transaction exceeds 4 MB.
  # - there is a user error, such as an invalid data format.
  #
  # A transaction can be interrupted simply by an exception raised within a
  # block. As far as no changes are actually persisted before the +#commit+
  # method call - there is nothing to undo on the DynamoDB's site.
  #
  # Raising +Dynamoid::Errors::Rollback+ exception leads to interrupting a
  # transation and it isn't propogated:
  #
  #   Dynamoid::TransactionWrite.execute do |t|
  #     t.save! user
  #     t.create! Account, name: 'A'
  #
  #     if user.is_admin?
  #       raise Dynamoid::Errors::Rollback
  #     end
  #   end
  #
  # When a transaction is successfully committed or rolled backed -
  # corresponding +#after_commit+ or +#after_rollback+ callbacks are run for
  # each involved model.
  class TransactionWrite
    def self.execute
      transaction = new

      begin
        yield transaction
      rescue => error
        transaction.rollback

        unless error.is_a?(Dynamoid::Errors::Rollback)
          raise error
        end
      else
        transaction.commit
      end
    end

    def initialize
      @actions = []
    end

    # Persist all the changes.
    #
    #   transaction = Dynamoid::TransactionWrite.new
    #   # ...
    #   transaction.commit
    def commit
      actions_to_commit = @actions.reject(&:aborted?).reject(&:skipped?)
      return if actions_to_commit.empty?

      action_requests = actions_to_commit.map(&:action_request)
      Dynamoid.adapter.transact_write_items(action_requests)
      actions_to_commit.each(&:on_commit)

      nil
    rescue Aws::Errors::ServiceError
      run_on_rollback_callbacks
      raise
    end

    def rollback
      run_on_rollback_callbacks
    end

    # Create new model or persist changes in already existing one.
    #
    # Run the validation and callbacks. Returns +true+ if saving is successful
    # and +false+ otherwise.
    #
    #   user = User.new
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.save!(user)
    #   end
    #
    # Validation can be skipped with +validate: false+ option:
    #
    #   user = User.new(age: -1)
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.save!(user, validate: false)
    #   end
    #
    # +save!+ by default sets timestamps attributes - +created_at+ and
    # +updated_at+ when creates new model and updates +updated_at+ attribute
    # when updates already existing one.
    #
    # If a model is new and hash key (+id+ by default) is not assigned yet
    # it was assigned implicitly with random UUID value.
    #
    # When a model is not persisted - its id should have unique value.
    # Otherwise a transaction will be rolled back.
    #
    # @param model [Dynamoid::Document] a model
    # @param options [Hash] (optional)
    # @option options [true|false] :validate validate a model or not - +true+ by default (optional)
    # @return [true|false] Whether saving successful or not
    def save!(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_error: true)
      register_action action
    end

    # Create new model or persist changes in already existing one.
    #
    # Run the validation and callbacks. Raise
    # +Dynamoid::Errors::DocumentNotValid+ unless this object is valid.
    #
    #   user = User.new
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.save(user)
    #   end
    #
    # Validation can be skipped with +validate: false+ option:
    #
    #   user = User.new(age: -1)
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.save(user, validate: false)
    #   end
    #
    # +save+ by default sets timestamps attributes - +created_at+ and
    # +updated_at+ when creates new model and updates +updated_at+ attribute
    # when updates already existing one.
    #
    # If a model is new and hash key (+id+ by default) is not assigned yet
    # it was assigned implicitly with random UUID value.
    #
    # When a model is not persisted - its id should have unique value.
    # Otherwise a transaction will be rolled back.
    #
    # @param model [Dynamoid::Document] a model
    # @param options [Hash] (optional)
    # @option options [true|false] :validate validate a model or not - +true+ by default (optional)
    # @return [true|false] Whether saving successful or not
    def save(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_error: false)
      register_action action
    end

    # Create a model.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create!(User, name: 'A')
    #   end
    #
    # Accepts both Hash and Array of Hashes and can create several models.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create!(User, [{name: 'A'}, {name: 'B'}, {name: 'C'}])
    #   end
    #
    # Instantiates a model and pass it into an optional block to set other
    # attributes.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create!(User, name: 'A') do |user|
    #       user.initialize_roles
    #     end
    #   end
    #
    # Validates model and runs callbacks.
    #
    # @param model_class [Class] a model class which should be instantiated
    # @param attributes [Hash|Array<Hash>] attributes of a model
    # @param block [Proc] a block to process a model after initialization
    # @return [Dynamoid::Document] a model that was instantiated but not yet persisted
    def create!(model_class, attributes = {}, &block)
      if attributes.is_a? Array
        attributes.map do |attr|
          action = Dynamoid::TransactionWrite::Create.new(model_class, attr, raise_error: true, &block)
          register_action action
        end
      else
        action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_error: true, &block)
        register_action action
      end
    end

    # Create a model.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create(User, name: 'A')
    #   end
    #
    # Accepts both Hash and Array of Hashes and can create several models.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create(User, [{name: 'A'}, {name: 'B'}, {name: 'C'}])
    #   end
    #
    # Instantiates a model and pass it into an optional block to set other
    # attributes.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.create(User, name: 'A') do |user|
    #       user.initialize_roles
    #     end
    #   end
    #
    # Validates model and runs callbacks.
    #
    # @param model_class [Class] a model class which should be instantiated
    # @param attributes [Hash|Array<Hash>] attributes of a model
    # @param block [Proc] a block to process a model after initialization
    # @return [Dynamoid::Document] a model that was instantiated but not yet persisted
    def create(model_class, attributes = {}, &block)
      if attributes.is_a? Array
        attributes.map do |attr|
          action = Dynamoid::TransactionWrite::Create.new(model_class, attr, raise_error: false, &block)
          register_action action
        end
      else
        action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_error: false, &block)
        register_action action
      end
    end

    # Update an existing document or create a new one.
    #
    # If a document with specified hash and range keys doesn't exist it
    # creates a new document with specified attributes. Doesn't run
    # validations and callbacks.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.upsert(User, '1', age: 26)
    #   end
    #
    # If range key is declared for a model it should be passed as well:
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.upsert(User, '1', 'Tylor', age: 26)
    #   end
    #
    # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
    # attributes is not declared in the model class.
    #
    # @param model_class [Class] a model class
    # @param hash_key [Scalar value] hash key value
    # @param range_key [Scalar value] range key value (optional)
    # @param attributes [Hash]
    # @return [nil]
    def upsert(model_class, hash_key, range_key = nil, attributes) # rubocop:disable Style/OptionalArguments
      action = Dynamoid::TransactionWrite::Upsert.new(model_class, hash_key, range_key, attributes)
      register_action action
    end

    # Update document.
    #
    # Doesn't run validations and callbacks.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.update_fields(User, '1', age: 26)
    #   end
    #
    # If range key is declared for a model it should be passed as well:
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.update_fields(User, '1', 'Tylor', age: 26)
    #   end
    #
    # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
    # attributes is not declared in the model class.
    #
    # @param model_class [Class] a model class
    # @param hash_key [Scalar value] hash key value
    # @param range_key [Scalar value] range key value (optional)
    # @param attributes [Hash]
    # @return [nil]
    def update_fields(model_class, hash_key, range_key = nil, attributes) # rubocop:disable Style/OptionalArguments
      action = Dynamoid::TransactionWrite::UpdateFields.new(model_class, hash_key, range_key, attributes)
      register_action action
    end

    # Update multiple attributes at once.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.update_attributes(user, age: 27, last_name: 'Tylor')
    #   end
    #
    # Returns +true+ if saving is successful and +false+
    # otherwise.
    #
    # @param model [Dynamoid::Document] a model
    # @param attributes [Hash] a hash of attributes to update
    # @return [true|false] Whether updating successful or not
    def update_attributes(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_error: false)
      register_action action
    end

    # Update multiple attributes at once.
    #
    # Returns +true+ if saving is successful and +false+
    # otherwise.
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.update_attributes(user, age: 27, last_name: 'Tylor')
    #   end
    #
    # Raises a +Dynamoid::Errors::DocumentNotValid+ exception if some vaidation
    # fails.
    #
    # @param model [Dynamoid::Document] a model
    # @param attributes [Hash] a hash of attributes to update
    def update_attributes!(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_error: true)
      register_action action
    end

    # Delete a model.
    #
    # Can be called either with a model:
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.delete(user)
    #   end
    #
    # or with a primary key:
    #
    #   Dynamoid::TransactionWrite.execute do |t|
    #     t.delete(User, user_id)
    #   end
    #
    # Raise +MissingRangeKey+ if a range key is declared but not passed as argument.
    #
    # @param model_or_model_class [Class|Dynamoid::Document] either model or model class
    # @param hash_key [Scalar value] hash key value
    # @param range_key [Scalar value] range key value (optional)
    # @return [Dynamoid::Document] self
    def delete(model_or_model_class, hash_key = nil, range_key = nil)
      action = if model_or_model_class.is_a? Class
                 Dynamoid::TransactionWrite::DeleteWithPrimaryKey.new(model_or_model_class, hash_key, range_key)
               else
                 Dynamoid::TransactionWrite::DeleteWithInstance.new(model_or_model_class)
               end
      register_action action
    end

    # Delete a model.
    #
    # Runs callbacks.
    #
    # Raises +Dynamoid::Errors::RecordNotDestroyed+ exception if model deleting
    # failed (e.g. aborted by a callback).
    #
    # @param model [Dynamoid::Document] a model
    # @return [Dynamoid::Document|false] returns self if destoying is succefull, +false+ otherwise
    def destroy!(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model, raise_error: true)
      register_action action
    end

    # Delete a model.
    #
    # Runs callbacks.
    #
    # @param model [Dynamoid::Document] a model
    # @return [Dynamoid::Document] self
    def destroy(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model, raise_error: false)
      register_action action
    end

    private

    def register_action(action)
      @actions << action
      action.on_registration
      action.observable_by_user_result
    end

    def run_on_rollback_callbacks
      actions_to_commit = @actions.reject(&:aborted?).reject(&:skipped?)
      actions_to_commit.each(&:on_rollback)
    end
  end
end
