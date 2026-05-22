# frozen_string_literal: true

require_relative 'mutation/create'
require_relative 'mutation/delete_with_primary_key'
require_relative 'mutation/delete_with_instance'
require_relative 'mutation/destroy'
require_relative 'mutation/save'
require_relative 'mutation/update_fields'
require_relative 'mutation/update_attributes'
require_relative 'mutation/upsert'
require_relative 'mutation/inc'
require_relative 'mutation/touch'
require_relative 'mutation/increment'
require_relative 'mutation/import'

module Dynamoid
  module Transactions
    # The +Mutation+ class provides a way to perform multiple modifying operations
    # atomically in a transaction—either all operations succeed, or all fail.
    #
    # The persistence methods are designed to mirror their non-transactional
    # counterparts like +.create+, +#save+, and +#delete+:
    #
    #   user = User.new(name: 'John')
    #   payment = Payment.find(1)
    #
    #   Dynamoid::Transactions::Mutation.execute do |t|
    #     t.save! user
    #     t.create! Account, name: 'A'
    #     t.delete payment
    #   end
    #
    # The primary difference is that these methods are called on a transaction
    # instance, and the model (or class) must be passed as an argument.
    #
    # For example, +user.save!+ becomes +t.save!(user)+, +Account.create!(name: 'A')+
    # becomes +t.create!(Account, name: 'A')+, and +payment.delete+ becomes
    # +t.delete(payment)+.
    #
    # Transactions can also be used without a block by manually instantiating
    # and committing:
    #
    #   t = Dynamoid::Transactions::Mutation.new
    #   t.save! user
    #   t.create! Account, name: 'A'
    #   t.delete payment
    #   t.commit
    #
    # Some persistence methods (like +.update+ and +.update!+) are intentionally
    # unavailable because they perform multiple underlying operations and cannot
    # be implemented atomically.
    #
    # ### DynamoDB Transactions
    #
    # Unlike many databases, DynamoDB transactions are executed in batch.
    # In Dynamoid, no changes are persisted when a method like +#save+ is called.
    # All changes are queued and sent to DynamoDB at the end of the transaction.
    #
    # This uses the DynamoDB +TransactWriteItems+ operation (see
    # [documentation](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_TransactWriteItems.html)).
    #
    # ### Callbacks
    #
    # Transactional methods support +before_+, +after_+, and +around_+ callbacks
    # to the same extent as their non-transactional counterparts.
    #
    # **Important difference:** Callbacks (even +after_+ ones) run immediately
    # when the method is called, *before* changes are actually persisted to
    # DynamoDB. Consequently, code in an +after_+ callback will not yet see the
    # updated data in DynamoDB.
    #
    # If a callback aborts the operation or a model is invalid, that specific
    # action is skipped, but the transaction itself may still commit successfully.
    #
    # ### Transaction Rollback
    #
    # A transaction is automatically rolled back on the DynamoDB side if:
    # - Another operation is currently updating the same item.
    # - Provisioned capacity is insufficient.
    # - Item or transaction size limits are exceeded (e.g., item > 400 KB or total > 4 MB).
    # - There is a user error (e.g., invalid data format).
    #
    # Since no changes are persisted until the +#commit+ call, a transaction can
    # be aborted by simply raising an exception within the block.
    #
    # Raising +Dynamoid::Errors::Rollback+ will interrupt the transaction without
    # propagating the exception further:
    #
    #   Dynamoid::Transactions::Mutation.execute do |t|
    #     t.save! user
    #     t.create! Account, name: 'A'
    #
    #     raise Dynamoid::Errors::Rollback if user.is_admin?
    #   end
    #
    # When a transaction is successfully committed or rolled back, the corresponding
    # +#after_commit+ or +#after_rollback+ callbacks are run for each involved model.
    class Mutation
      def self.execute
        transaction = new

        begin
          yield transaction
        rescue StandardError => e
          transaction.rollback

          unless e.is_a?(Dynamoid::Errors::Rollback)
            raise e
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
      #   transaction = Dynamoid::Transactions::Mutation.new
      #   # ...
      #   transaction.commit
      def commit
        actions_to_commit = @actions.reject(&:aborted?).reject(&:skipped?)
        return if actions_to_commit.empty?

        action_requests = actions_to_commit.flat_map(&:action_requests)
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

      # Update the +updated_at+ timestamp and optionally other specified
      # attributes.
      #
      # Runs callbacks.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.touch(user)
      #   end
      #
      # If attribute names are passed, they are updated along with updated_at
      # attribute:
      #
      #   t.touch(user, :viewed_at)
      #   t.touch(user, :viewed_at, :accessed_at)
      #
      #   t.touch(user, time: 2.days.ago)
      #
      # Raises +Dynamoid::Errors::Error+ if a model is new or destroyed.
      #
      # @param model [Dynamoid::Document] a model
      # @param names [Array<Symbol>] (optional) attribute names to update
      # @param time [Time] datetime value that can be used instead of the current time (optional)
      # @return [Dynamoid::Document] self
      def touch(model, *names, time: nil)
        action = Touch.new(model, *names, time: time)
        register_action action
      end

      # Create new model or persist changes in already existing one.
      #
      # Run the validation and callbacks. Returns +true+ if saving is successful
      # and +false+ otherwise.
      #
      #   user = User.new
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.save!(user)
      #   end
      #
      # Validation can be skipped with +validate: false+ option:
      #
      #   user = User.new(age: -1)
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
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
      # Raises +Dynamoid::Errors::MissingHashKey+ if a model is already persisted
      # and a partition key has value +nil+ and raises
      # +Dynamoid::Errors::MissingRangeKey+ if a sort key is required but has
      # value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#save!+:
      # - transactional +#save!+ doesn't support the +:touch+ option
      # - transactional +#save!+ doesn't raise +Dynamoid::Errors::StaleObjectError+
      #   when optimistic concurrency control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - transactional +#save!+ doesn't raise +Dynamoid::Errors::RecordNotUnique+
      #   at saving new model when primary key is already used. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - transactional +save!+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when a model that is being updated
      #   was concurrently deleted
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model [Dynamoid::Document] a model
      # @param options [Hash] (optional)
      # @option options [true|false] :validate validate a model or not - +true+ by default (optional)
      # @return [true|false] Whether saving successful or not
      def save!(model, **options)
        action = Save.new(model, **options, raise_error: true)
        register_action action
      end

      # Create new model or persist changes in already existing one.
      #
      # Run the validation and callbacks. Raise
      # +Dynamoid::Errors::DocumentNotValid+ unless this object is valid.
      #
      #   user = User.new
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.save(user)
      #   end
      #
      # Validation can be skipped with +validate: false+ option:
      #
      #   user = User.new(age: -1)
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
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
      # Raises +Dynamoid::Errors::MissingHashKey+ if a model is already persisted
      # and a partition key has value +nil+ and raises
      # +Dynamoid::Errors::MissingRangeKey+ if a sort key is required but has
      # value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#save+:
      # - transactional +#save+ doesn't support the +:touch+ option
      # - transactional +#save+ doesn't raise +Dynamoid::Errors::StaleObjectError+
      #   when optimistic concurrency control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - transactional +#save+ doesn't raise +Dynamoid::Errors::RecordNotUnique+
      #   at saving new model when primary key is already used. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - transactional +save+ doesn't raise +Dynamoid::Errors::StaleObjectError+
      #   when a model that is being updated was concurrently deleted
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model [Dynamoid::Document] a model
      # @param options [Hash] (optional)
      # @option options [true|false] :validate validate a model or not - +true+ by default (optional)
      # @return [true|false] Whether saving successful or not
      def save(model, **options)
        action = Save.new(model, **options, raise_error: false)
        register_action action
      end

      # Create a model.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create!(User, name: 'A')
      #   end
      #
      # Accepts both Hash and Array of Hashes and can create several models.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create!(User, [{name: 'A'}, {name: 'B'}, {name: 'C'}])
      #   end
      #
      # Instantiates a model and pass it into an optional block to set other
      # attributes.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create!(User, name: 'A') do |user|
      #       user.initialize_roles
      #     end
      #   end
      #
      # Validates model and runs callbacks.
      #
      # Raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is required but
      # not specified or has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#create+:
      # - transactional +#create!+ doesn't raise +Dynamoid::Errors::RecordNotUnique+
      #   at saving new model when primary key is already used. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model_class [Class] a model class which should be instantiated
      # @param attributes [Hash|Array<Hash>] attributes of a model
      # @param block [Proc] a block to process a model after initialization
      # @return [Dynamoid::Document] a model that was instantiated but not yet persisted
      def create!(model_class, attributes = {}, &block)
        if attributes.is_a? Array
          attributes.map do |attr|
            action = Create.new(model_class, attr, raise_error: true, &block)
            register_action action
          end
        else
          action = Create.new(model_class, attributes, raise_error: true, &block)
          register_action action
        end
      end

      # Create a model.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create(User, name: 'A')
      #   end
      #
      # Accepts both Hash and Array of Hashes and can create several models.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create(User, [{name: 'A'}, {name: 'B'}, {name: 'C'}])
      #   end
      #
      # Instantiates a model and pass it into an optional block to set other
      # attributes.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.create(User, name: 'A') do |user|
      #       user.initialize_roles
      #     end
      #   end
      #
      # Validates model and runs callbacks.
      #
      # Raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is required but
      # not specified or has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#create+:
      # - transactional +#create+ doesn't raise +Dynamoid::Errors::RecordNotUnique+
      #   at saving new model when primary key is already used. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised instead.
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model_class [Class] a model class which should be instantiated
      # @param attributes [Hash|Array<Hash>] attributes of a model
      # @param block [Proc] a block to process a model after initialization
      # @return [Dynamoid::Document] a model that was instantiated but not yet persisted
      def create(model_class, attributes = {}, &block)
        if attributes.is_a? Array
          attributes.map do |attr|
            action = Create.new(model_class, attr, raise_error: false, &block)
            register_action action
          end
        else
          action = Create.new(model_class, attributes, raise_error: false, &block)
          register_action action
        end
      end

      # Update an existing document or create a new one.
      #
      # If a document with specified hash and range keys doesn't exist it
      # creates a new document with specified attributes. Doesn't run
      # validations and callbacks.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.upsert(User, '1', age: 26)
      #   end
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.upsert(User, '1', 'Tylor', age: 26)
      #   end
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not declared in the model class.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and +Dynamoid::Errors::MissingRangeKey+ if a sort key is required
      # but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#upsert+:
      # - transactional +#upsert+ doesn't support conditions (that's +if+ and
      #   +unless_exists+ options)
      # - transactional +#upsert+ doesn't return a document that was updated or
      #   created
      #
      # @param model_class [Class] a model class
      # @param hash_key [Scalar value] hash key value
      # @param range_key [Scalar value] range key value (optional)
      # @param attributes [Hash]
      # @return [nil]
      def upsert(model_class, hash_key, range_key = nil, attributes) # rubocop:disable Style/OptionalArguments
        action = Upsert.new(model_class, hash_key, range_key, attributes)
        register_action action
      end

      # Update document.
      #
      # Doesn't run validations and callbacks.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_fields(User, '1', age: 26)
      #   end
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_fields(User, '1', 'Tylor', age: 26)
      #   end
      #
      # Updates can also be performed in a block.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_fields(User, 1) do |u|
      #       u.add(article_count: 1)
      #       u.delete(favorite_colors: 'green')
      #       u.set(age: 27, last_name: 'Tylor')
      #     end
      #   end
      #
      # Operation +add+ just adds a value for numeric attributes and join
      # collections if attribute is a set.
      #
      #   t.update_fields(User, 1) do |u|
      #     u.add(age: 1, followers_count: 5)
      #     u.add(hobbies: ['skying', 'climbing'])
      #   end
      #
      # Operation +delete+ is applied to collection attribute types and
      # substructs one collection from another.
      #
      #   t.update_fields(User, 1) do |u|
      #     u.delete(hobbies: ['skying'])
      #   end
      #
      # Operation +set+ just changes an attribute value:
      #
      #   t.update_fields(User, 1) do |u|
      #     u.set(age: 21)
      #   end
      #
      # Operation +remove+ removes one or more attributes from an item.
      #
      #   t.update_fields(User, 1) do |u|
      #     u.remove(:age)
      #   end
      #
      # All the operations work like +ADD+, +DELETE+, +REMOVE+, and +SET+ actions supported
      # by +UpdateExpression+
      # {parameter}[https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.UpdateExpressions.html]
      # of +UpdateItem+ operation.
      #
      # It's atomic operations. So adding or deleting elements in a collection
      # or incrementing or decrementing a numeric field is atomic and does not
      # interfere with other write requests.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not declared in the model class.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and +Dynamoid::Errors::MissingRangeKey+ if a sort key is required
      # but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#update_fields+:
      # - transactional +#update_fields+ doesn't support conditions (that's +if+
      #   and +unless_exists+ options)
      # - transactional +#update_fields+ doesn't return a document that was
      #   updated or created
      #
      # @param model_class [Class] a model class
      # @param hash_key [Scalar value] hash key value
      # @param range_key [Scalar value] range key value (optional)
      # @param attributes [Hash]
      # @return [nil]
      def update_fields(model_class, hash_key, range_key = nil, attributes = nil, &block)
        # given no attributes, but there may be a block
        if range_key.is_a?(Hash) && !attributes
          attributes = range_key
          range_key = nil
        end

        action = UpdateFields.new(model_class, hash_key, range_key, attributes, &block)
        register_action action
      end

      # Increment numeric attributes.
      #
      # Doesn't run validations and callbacks.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.inc(User, '1', age: 1)
      #   end
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.inc(User, '1', 'Tylor', age: 1)
      #   end
      #
      # It also supports +touch+ option to update +updated_at+ attribute and
      # optionally other specified attributes.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.inc(User, '1', age: 1, touch: true)
      #   end
      #
      # If attribute names are passed, they are updated along with updated_at
      # attribute:
      #
      #   t.inc(User, '1', age: 2, touch: :viewed_at)
      #   t.inc(User, '1', age: 2, touch: [:viewed_at, :accessed_at])
      #
      # It's an atomic operation. So incrementing or decrementing a numeric
      # field is atomic and does not interfere with other write requests.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not declared in the model class.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and +Dynamoid::Errors::MissingRangeKey+ if a sort key is required
      # but has value +nil+.
      #
      # @param model_class [Class] a model class
      # @param hash_key [Scalar value] hash key value
      # @param range_key [Scalar value] range key value (optional)
      # @param counters [Hash]
      # @return [nil]
      def inc(model_class, hash_key, range_key = nil, counters = nil)
        if range_key.is_a?(Hash) && !counters
          counters = range_key
          range_key = nil
        end

        action = Inc.new(model_class, hash_key, range_key, counters)
        register_action action
      end

      # Change numeric attribute value and save a model.
      #
      # Initializes attribute to zero if +nil+ and adds the specified value (by
      # default is 1). Only makes sense for number-based attributes.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.increment!(user, :followers_count)
      #     t.increment!(user, :followers_count, 2)
      #   end
      #
      # Only `attribute` is saved. The model itself is not saved. So any other
      # modified attributes will still be dirty. Validations and callbacks are
      # skipped.
      #
      # When `:touch` option is passed the timestamp columns are updating. If
      # attribute names are passed, they are updated along with updated_at
      # attribute:
      #
      #   t.increment!(user, :followers_count, touch: true)
      #   t.increment!(user, :followers_count, touch: :viewed_at)
      #   t.increment!(user, :followers_count, touch: [:viewed_at, :accessed_at])
      #
      # @param model [Dynamoid::Document] a model
      # @param attribute [Symbol] attribute name
      # @param by [Numeric] value to add (optional)
      # @param touch [true | Symbol | Array<Symbol>] to update update_at attribute and optionally the specified ones
      # @return [Dynamoid::Document] self
      def increment!(model, attribute, by = 1, touch: nil)
        action = Increment.new(model, attribute, by, touch: touch)
        register_action action
      end

      # Change numeric attribute value and save a model.
      #
      # Initializes attribute to zero if +nil+ and subtracts the specified value
      # (by default is 1). Only makes sense for number-based attributes.
      #
      # Runs callbacks.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.decrement!(user, :followers_count)
      #     t.decrement!(user, :followers_count, 2)
      #   end
      #
      # Only `attribute` is saved. The model itself is not saved. So any other
      # modified attributes will still be dirty. Validations are skipped.
      #
      # When `:touch` option is passed the timestamp columns are updating. If
      # attribute names are passed, they are updated along with updated_at
      # attribute:
      #
      #   t.decrement!(user, :followers_count, touch: true)
      #   t.decrement!(user, :followers_count, touch: :viewed_at)
      #   t.decrement!(user, :followers_count, touch: [:viewed_at, :accessed_at])
      #
      # @param model [Dynamoid::Document] a model
      # @param attribute [Symbol] attribute name
      # @param by [Numeric] value to subtract (optional)
      # @param touch [true | Symbol | Array<Symbol>] to update update_at attribute and optionally the specified ones
      # @return [Dynamoid::Document] self
      def decrement!(model, attribute, by = 1, touch: nil)
        increment!(model, attribute, -by, touch: touch)
      end

      # Update multiple attributes at once.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_attributes(user, age: 27, last_name: 'Tylor')
      #   end
      #
      # Returns +true+ if saving is successful and +false+
      # otherwise.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is
      # required but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#update_attributes+:
      # - transactional +#update_attributes+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when optimistic concurrency
      #   control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised
      #   instead.
      # - transactional +update_attributes+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when a model that is being updated
      #   was concurrently deleted
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model [Dynamoid::Document] a model
      # @param attributes [Hash] a hash of attributes to update
      # @return [true|false] Whether updating successful or not
      def update_attributes(model, attributes)
        action = UpdateAttributes.new(model, attributes, raise_error: false)
        register_action action
      end

      # Update multiple attributes at once.
      #
      # Returns +true+ if saving is successful and +false+
      # otherwise.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_attributes(user, age: 27, last_name: 'Tylor')
      #   end
      #
      # Raises a +Dynamoid::Errors::DocumentNotValid+ exception if some vaidation
      # fails.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is
      # required but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#update_attributes!+:
      # - transactional +#update_attributes!+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when optimistic concurrency
      #   control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised
      #   instead.
      # - transactional +update_attributes!+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when a model that is being updated
      #   was concurrently deleted
      # - a table isn't created lazily if it doesn't exist yet
      #
      # @param model [Dynamoid::Document] a model
      # @param attributes [Hash] a hash of attributes to update
      def update_attributes!(model, attributes)
        action = UpdateAttributes.new(model, attributes, raise_error: true)
        register_action action
      end

      # Update a single attribute, saving the object afterwards.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_attribute(user, :last_name, 'Tylor')
      #   end
      #
      # Validation is skipped.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not on the model
      #
      # @param model [Dynamoid::Document] a model
      # @param attribute [Symbol] attribute name to update
      # @param value [Object] the value to assign it
      # @return [Dynamoid::Document] self
      def update_attribute(model, attribute, value)
        model.write_attribute(attribute, value)
        save(model, validate: false)
      end

      # Update a single attribute, saving the object afterwards.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.update_attribute!(user, :last_name, 'Tylor')
      #   end
      #
      # Validation is skipped.
      #
      # If any of the `before_*` callbacks throws `:abort` the action is
      # cancelled and `update_attribute!` raises
      # Dynamoid::Errors::RecordNotSaved.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not on the model
      #
      # @param model [Dynamoid::Document] a model
      # @param attribute [Symbol] attribute name to update
      # @param value [Object] the value to assign it
      # @return [Dynamoid::Document] self
      def update_attribute!(model, attribute, value)
        model.write_attribute(attribute, value)
        save!(model, validate: false)
        model
      end

      # Delete a model.
      #
      # Can be called either with a model:
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.delete(user)
      #   end
      #
      # or with a primary key:
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.delete(User, user_id)
      #   end
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is
      # required but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#delete+: TBD
      # - transactional +#delete+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when optimistic concurrency
      #   control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised
      #   instead.
      # - transactional +#delete+ doesn't disassociate a model from associated ones
      #   if there is any
      #
      # @param model_or_model_class [Class|Dynamoid::Document] either model or model class
      # @param hash_key [Scalar value] hash key value
      # @param range_key [Scalar value] range key value (optional)
      # @return [Dynamoid::Document] self
      def delete(model_or_model_class, hash_key = nil, range_key = nil)
        action = if model_or_model_class.is_a? Class
                   DeleteWithPrimaryKey.new(model_or_model_class, hash_key, range_key)
                 else
                   DeleteWithInstance.new(model_or_model_class)
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
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is
      # required but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#destroy!+:
      # - transactional +#destroy!+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when optimistic concurrency
      #   control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised
      #   instead.
      # - transactional +#destroy!+ doesn't disassociate a model from associated ones
      #   if there are association declared in the model class
      #
      # @param model [Dynamoid::Document] a model
      # @return [Dynamoid::Document|false] returns self if destoying is succefull, +false+ otherwise
      def destroy!(model)
        action = Destroy.new(model, raise_error: true)
        register_action action
      end

      # Delete a model.
      #
      # Runs callbacks.
      #
      # Raises +Dynamoid::Errors::MissingHashKey+ if a partition key has value
      # +nil+ and raises +Dynamoid::Errors::MissingRangeKey+ if a sort key is
      # required but has value +nil+.
      #
      # There are the following differences between transactional and
      # non-transactional +#destroy+:
      # - transactional +#destroy+ doesn't raise
      #   +Dynamoid::Errors::StaleObjectError+ when optimistic concurrency
      #   control detects a conflict. A generic
      #   +Aws::DynamoDB::Errors::TransactionCanceledException+ is raised
      #   instead.
      # - transactional +#destroy+ doesn't disassociate a model from associated ones
      #   if there are association declared in the model class
      #
      # @param model [Dynamoid::Document] a model
      # @return [Dynamoid::Document] self
      def destroy(model)
        action = Destroy.new(model, raise_error: false)
        register_action action
      end

      # Create multiple models from an array of attribute hashes.
      #
      # Validations and callbacks are skipped.
      #
      #   Dynamoid::Transactions::Mutation.execute do |t|
      #     t.import(User, [{ name: 'A' }, { name: 'B' }])
      #   end
      #
      # Since DynamoDB limits the total number of actions per transaction,
      # each model created via +#import+ consumes one action from this limit.
      #
      # @param model_class [Class] a model class
      # @param array_of_attributes [Array<Hash>] attributes of models
      # @return [Array<Dynamoid::Document>] created models
      def import(model_class, array_of_attributes)
        action = Import.new(model_class, array_of_attributes)
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
end
