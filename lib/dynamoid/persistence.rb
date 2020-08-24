# frozen_string_literal: true

require 'bigdecimal'
require 'securerandom'
require 'yaml'

require 'dynamoid/persistence/import'
require 'dynamoid/persistence/update_fields'
require 'dynamoid/persistence/upsert'
require 'dynamoid/persistence/save'
require 'dynamoid/persistence/update_validations'
require 'dynamoid/persistence/transact'

# encoding: utf-8
module Dynamoid
  #   # Persistence is responsible for dumping objects to and marshalling objects from the datastore. It tries to reserialize
  #   # values to be of the same type as when they were passed in, based on the fields in the class.
  module Persistence
    extend ActiveSupport::Concern

    attr_accessor :new_record
    alias new_record? new_record

    # @private
    UNIX_EPOCH_DATE = Date.new(1970, 1, 1).freeze

    module ClassMethods
      def table_name
        table_base_name = options[:name] || base_class.name.split('::').last.downcase.pluralize

        @table_name ||= [Dynamoid::Config.namespace.to_s, table_base_name].reject(&:empty?).join('_')
      end

      # Create a table.
      #
      # Uses a configuration specified in a model class (with the +table+
      # method) e.g. table name, schema (hash and range keys), global and local
      # secondary indexes, billing mode and write/read capacity.
      #
      # For instance here
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     table key: :uuid
      #     range :last_name
      #
      #     field :first_name
      #     field :last_name
      #   end
      #
      #   User.create_table
      #
      # +create_table+ method call will create a table +dynamoid_users+ with
      # hash key +uuid+ and range key +name+, DynamoDB default billing mode and
      # Dynamoid default read/write capacity units (100/20).
      #
      # All the configuration can be overridden with +options+ argument.
      #
      #   User.create_table(table_name: 'users', read_capacity: 200, write_capacity: 40)
      #
      # Dynamoid creates a table synchronously by default. DynamoDB table
      # creation is an asynchronous operation and a client should wait until a
      # table status changes to +ACTIVE+ and a table becomes available. That's
      # why Dynamoid is polling a table status and returns results only when a
      # table becomes available.
      #
      # Polling is configured with +Dynamoid::Config.sync_retry_max_times+ and
      # +Dynamoid::Config.sync_retry_wait_seconds+ configuration options. If
      # table creation takes more time than configured waiting time then
      # Dynamoid stops polling and returns +true+.
      #
      # In order to return back asynchronous behaviour and not to wait until a
      # table is created the +sync: false+ option should be specified.
      #
      #   User.create_table(sync: false)
      #
      # Subsequent method calls for the same table will be ignored.
      #
      # @param options [Hash]
      #
      # @option options [Symbol] :table_name name of the table
      # @option options [Symbol] :id hash key name of the table
      # @option options [Symbol] :hash_key_type Dynamoid type of the hash key - +:string+, +:integer+ or any other scalar type
      # @option options [Hash] :range_key a Hash with range key name and type in format +{ <name> => <type> }+ e.g. +{ last_name: :string }+
      # @option options [String] :billing_mode billing mode of a table - either +PROVISIONED+ (default) or +PAY_PER_REQUEST+ (for On-Demand Mode)
      # @option options [Integer] :read_capacity read capacity units for the table; does not work on existing tables and is ignored when billing mode is +PAY_PER_REQUEST+
      # @option options [Integer] :write_capacity write capacity units for the table; does not work on existing tables and is ignored when billing mode is +PAY_PER_REQUEST+
      # @option options [Hash] :local_secondary_indexes
      # @option options [Hash] :global_secondary_indexes
      # @option options [true|false] :sync specifies should the method call be synchronous and wait until a table is completely created
      #
      # @return [true|false] Whether a table created successfully
      # @since 0.4.0
      def create_table(options = {})
        range_key_hash = if range_key
                           { range_key => PrimaryKeyTypeMapping.dynamodb_type(attributes[range_key][:type], attributes[range_key]) }
                         end

        options = {
          id: hash_key,
          table_name: table_name,
          billing_mode: capacity_mode,
          write_capacity: write_capacity,
          read_capacity: read_capacity,
          range_key: range_key_hash,
          hash_key_type: PrimaryKeyTypeMapping.dynamodb_type(attributes[hash_key][:type], attributes[hash_key]),
          local_secondary_indexes: local_secondary_indexes.values,
          global_secondary_indexes: global_secondary_indexes.values
        }.merge(options)

        created_successfuly = Dynamoid.adapter.create_table(options[:table_name], options[:id], options)

        if created_successfuly && self.options[:expires]
          attribute = self.options[:expires][:field]
          Dynamoid.adapter.update_time_to_live(table_name: table_name, attribute: attribute)
        end
      end

      # Deletes the table for the model.
      #
      # Dynamoid deletes a table asynchronously and doesn't wait until a table
      # is deleted completely.
      #
      # Subsequent method calls for the same table will be ignored.
      def delete_table
        Dynamoid.adapter.delete_table(table_name)
      end

      # @private
      def from_database(attrs = {})
        klass = choose_right_class(attrs)
        attrs_undumped = Undumping.undump_attributes(attrs, klass.attributes)
        klass.new(attrs_undumped).tap { |r| r.new_record = false }
      end

      # Create several models at once.
      #
      #   users = User.import([{ name: 'a' }, { name: 'b' }])
      #
      # +import+ is a relatively low-level method and bypasses some
      # mechanisms like callbacks and validation.
      #
      # It sets timestamp fields +created_at+ and +updated_at+ if they are
      # blank. It sets a hash key field as well if it's blank. It expects that
      # the hash key field is +string+ and sets a random UUID value if the field
      # value is blank. All the field values are type casted to the declared
      # types.
      #
      # It works efficiently and uses the `BatchWriteItem` operation. In order
      # to cope with throttling it uses a backoff strategy if it's specified with
      # `Dynamoid::Config.backoff` configuration option.
      #
      # Because of the nature of DynamoDB and its limits only 25 models can be
      # saved at once. So multiple HTTP requests can be sent to DynamoDB.
      #
      # @param array_of_attributes [Array<Hash>]
      # @return [Array] Created models
      def import(array_of_attributes)
        Import.call(self, array_of_attributes)
      end

      # perfom multiple atomic operations synchronously
      #
      # similar to +import+ transact is a low-level method and won't have
      # mechanisms like callback and validation
      #
      # users = User.transact({condition_check: {}, put: {}, delete: {}, update: {}})
      # @param array_of_attributes [Array<Hash>]
      # @return [Array] Created models
      def transact(list_of_operations)
        Transact.call(self, list_of_operations)
      end

      # Create a model.
      #
      # Initializes a new model and immediately saves it to DynamoDB.
      #
      #   User.create(first_name: 'Mark', last_name: 'Tyler')
      #
      # Accepts both Hash and Array of Hashes and can create several models.
      #
      #   User.create([{ first_name: 'Alice' }, { first_name: 'Bob' }])
      #
      # Creates a model and pass it into a block to set other attributes.
      #
      #   User.create(first_name: 'Mark') do |u|
      #     u.age = 21
      #   end
      #
      # Validates model and runs callbacks.
      #
      # @param attrs [Hash|Array[Hash]] Attributes of the models
      # @param block [Proc] Block to process a document after initialization
      # @return [Dynamoid::Document] The created document
      # @since 0.2.0
      def create(attrs = {}, &block)
        if attrs.is_a?(Array)
          attrs.map { |attr| create(attr, &block) }
        else
          build(attrs, &block).tap(&:save)
        end
      end

      # Create a model.
      #
      # Initializes a new object and immediately saves it to the Dynamoid.
      # Raises an exception +Dynamoid::Errors::DocumentNotValid+ if validation
      # failed. Accepts both Hash and Array of Hashes and can create several
      # models.
      #
      # @param attrs [Hash|Array[Hash]] Attributes with which to create the object.
      # @param block [Proc] Block to process a document after initialization
      # @return [Dynamoid::Document] The created document
      # @since 0.2.0
      def create!(attrs = {}, &block)
        if attrs.is_a?(Array)
          attrs.map { |attr| create!(attr, &block) }
        else
          build(attrs, &block).tap(&:save!)
        end
      end

      # Update document with provided attributes.
      #
      # Instantiates document and saves changes. Runs validations and
      # callbacks. Don't save changes if validation fails.
      #
      #   User.update('1', age: 26)
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   User.update('1', 'Tylor', age: 26)
      #
      # @param hash_key [Scalar value] hash key
      # @param range_key_value [Scalar value] range key (optional)
      # @param attrs [Hash]
      # @return [Dynamoid::Document] Updated document
      def update(hash_key, range_key_value = nil, attrs)
        model = find(hash_key, range_key: range_key_value, consistent_read: true)
        model.update_attributes(attrs)
        model
      end

      # Update document with provided attributes.
      #
      # Instantiates document and saves changes. Runs validations and
      # callbacks.
      #
      #   User.update!('1', age: 26)
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   User.update('1', 'Tylor', age: 26)
      #
      # Raises +Dynamoid::Errors::DocumentNotValid+ exception if validation fails.
      #
      # @param hash_key [Scalar value] hash key
      # @param range_key_value [Scalar value] range key (optional)
      # @param attrs [Hash]
      # @return [Dynamoid::Document] Updated document
      def update!(hash_key, range_key_value = nil, attrs)
        model = find(hash_key, range_key: range_key_value, consistent_read: true)
        model.update_attributes!(attrs)
        model
      end

      # Update document.
      #
      # Doesn't run validations and callbacks.
      #
      #   User.update_fields('1', age: 26)
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   User.update_fields('1', 'Tylor', age: 26)
      #
      # Can make a conditional update so a document will be updated only if it
      # meets the specified conditions. Conditions can be specified as a +Hash+
      # with +:if+ key:
      #
      #   User.update_fields('1', { age: 26 }, if: { version: 1 })
      #
      # Here +User+ model has an integer +version+ field and the document will
      # be updated only if the +version+ attribute currently has value 1.
      #
      # If a document with specified hash and range keys doesn't exist or
      # conditions were specified and failed the method call returns +nil+.
      #
      # +update_fields+ uses the +UpdateItem+ operation so it saves changes and
      # loads an updated document back with one HTTP request.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not on the model
      #
      # @param hash_key_value [Scalar value] hash key
      # @param range_key_value [Scalar value] range key (optional)
      # @param attrs [Hash]
      # @param conditions [Hash] (optional)
      # @return [Dynamoid::Document|nil] Updated document
      def update_fields(hash_key_value, range_key_value = nil, attrs = {}, conditions = {})
        optional_params = [range_key_value, attrs, conditions].compact
        if optional_params.first.is_a?(Hash)
          range_key_value = nil
          attrs, conditions = optional_params[0..1]
        else
          range_key_value = optional_params.first
          attrs, conditions = optional_params[1..2]
        end

        UpdateFields.call(self,
                          partition_key: hash_key_value,
                          sort_key: range_key_value,
                          attributes: attrs,
                          conditions: conditions)
      end

      # Update an existing document or create a new one.
      #
      # If a document with specified hash and range keys doesn't exist it
      # creates a new document with specified attributes. Doesn't run
      # validations and callbacks.
      #
      #   User.upsert('1', age: 26)
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   User.upsert('1', 'Tylor', age: 26)
      #
      # Can make a conditional update so a document will be updated only if it
      # meets the specified conditions. Conditions can be specified as a +Hash+
      # with +:if+ key:
      #
      #   User.upsert('1', { age: 26 }, if: { version: 1 })
      #
      # Here +User+ model has an integer +version+ field and the document will
      # be updated only if the +version+ attribute currently has value 1.
      #
      # If conditions were specified and failed the method call returns +nil+.
      #
      # +upsert+ uses the +UpdateItem+ operation so it saves changes and loads
      # an updated document back with one HTTP request.
      #
      # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
      # attributes is not on the model
      #
      # @param hash_key_value [Scalar value] hash key
      # @param range_key_value [Scalar value] range key (optional)
      # @param attrs [Hash]
      # @param conditions [Hash] (optional)
      # @return [Dynamoid::Document|nil] Updated document
      def upsert(hash_key_value, range_key_value = nil, attrs = {}, conditions = {})
        optional_params = [range_key_value, attrs, conditions].compact
        if optional_params.first.is_a?(Hash)
          range_key_value = nil
          attrs, conditions = optional_params[0..1]
        else
          range_key_value = optional_params.first
          attrs, conditions = optional_params[1..2]
        end

        Upsert.call(self,
                    partition_key: hash_key_value,
                    sort_key: range_key_value,
                    attributes: attrs,
                    conditions: conditions)
      end

      # Increase a numeric field by specified value.
      #
      #   User.inc('1', age: 2)
      #
      # Can update several fields at once.
      #
      #   User.inc('1', age: 2, version: 1)
      #
      # If range key is declared for a model it should be passed as well:
      #
      #   User.inc('1', 'Tylor', age: 2)
      #
      # Uses efficient low-level +UpdateItem+ operation and does only one HTTP
      # request.
      #
      # Doesn't run validations and callbacks. Doesn't update +created_at+ and
      # +updated_at+ as well.
      #
      # @param hash_key_value [Scalar value] hash key
      # @param range_key_value [Scalar value] range key (optional)
      # @param counters [Hash] value to increase by
      def inc(hash_key_value, range_key_value = nil, counters)
        options = if range_key
                    value_casted = TypeCasting.cast_field(range_key_value, attributes[range_key])
                    value_dumped = Dumping.dump_field(value_casted, attributes[range_key])
                    { range_key: value_dumped }
                  else
                    {}
                  end

        Dynamoid.adapter.update_item(table_name, hash_key_value, options) do |t|
          counters.each do |k, v|
            value_casted = TypeCasting.cast_field(v, attributes[k])
            value_dumped = Dumping.dump_field(value_casted, attributes[k])

            t.add(k => value_dumped)
          end
        end
      end
    end

    # Update document timestamps.
    #
    # Set +updated_at+ attribute to current DateTime.
    #
    #   post.touch
    #
    # Can update another field in addition with the same timestamp if it's name passed as argument.
    #
    #   user.touch(:last_login_at)
    #
    # @param name [Symbol] attribute name to update (optional)
    def touch(name = nil)
      now = DateTime.now
      self.updated_at = now
      attributes[name] = now if name
      save
    end

    # Is this object persisted in DynamoDB?
    #
    #   user = User.new
    #   user.persisted? # => false
    #
    #   user.save
    #   user.persisted? # => true
    #
    # @return [true|false]
    # @since 0.2.0
    def persisted?
      !(new_record? || @destroyed)
    end

    # Create new model or persist changes.
    #
    # Run the validation and callbacks. Returns +true+ if saving is successful
    # and +false+ otherwise.
    #
    #   user = User.new
    #   user.save # => true
    #
    #   user.age = 26
    #   user.save # => true
    #
    # Validation can be skipped with +validate: false+ option:
    #
    #   user = User.new(age: -1)
    #   user.save(validate: false) # => true
    #
    # +save+ by default sets timestamps attributes - +created_at+ and
    # +updated_at+ when creates new model and updates +updated_at+ attribute
    # when update already existing one.
    #
    # Changing +updated_at+ attribute at updating a model can be skipped with
    # +touch: false+ option:
    #
    #   user.save(touch: false)
    #
    # If a model is new and hash key (+id+ by default) is not assigned yet
    # it was assigned implicitly with random UUID value.
    #
    # If +lock_version+ attribute is declared it will be incremented. If it's blank then it will be initialized with 1.
    #
    # +save+ method call raises +Dynamoid::Errors::RecordNotUnique+ exception
    # if primary key (hash key + optional range key) already exists in a
    # table.
    #
    # +save+ method call raises +Dynamoid::Errors::StaleObjectError+ exception
    # if there is +lock_version+ attribute and the document in a table was
    # already changed concurrently and +lock_version+ was consequently
    # increased.
    #
    # When a table is not created yet the first +save+ method call will create
    # a table. It's useful in test environment to avoid explicit table
    # creation.
    #
    # @param options [Hash] (optional)
    # @option options [true|false] :validate validate a model or not - +true+ by default (optional)
    # @option options [true|false] :touch update tiemstamps fields or not - +true+ by default (optional)
    # @return [true|false] Whether saving successful or not
    # @since 0.2.0
    def save(options = {})
      self.class.create_table(sync: true)

      @_touch_record = options[:touch]

      if new_record?
        run_callbacks(:create) do
          run_callbacks(:save) do
            Save.call(self)
          end
        end
      else
        run_callbacks(:save) do
          Save.call(self)
        end
      end
    end

    # Update multiple attributes at once, saving the object once the updates
    # are complete. Returns +true+ if saving is successful and +false+
    # otherwise.
    #
    #   user.update_attributes(age: 27, last_name: 'Tylor')
    #
    # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
    # attributes is not on the model
    #
    # @param attributes [Hash] a hash of attributes to update
    # @return [true|false] Whether updating successful or not
    # @since 0.2.0
    def update_attributes(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) }
      save
    end

    # Update multiple attributes at once, saving the object once the updates
    # are complete.
    #
    #   user.update_attributes!(age: 27, last_name: 'Tylor')
    #
    # Raises a +Dynamoid::Errors::DocumentNotValid+ exception if some vaidation
    # fails.
    #
    # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
    # attributes is not on the model
    #
    # @param attributes [Hash] a hash of attributes to update
    def update_attributes!(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) }
      save!
    end

    # Update a single attribute, saving the object afterwards.
    #
    # Returns +true+ if saving is successful and +false+ otherwise.
    #
    #   user.update_attribute(:last_name, 'Tylor')
    #
    # Raises a +Dynamoid::Errors::UnknownAttribute+ exception if any of the
    # attributes is not on the model
    #
    # @param attribute [Symbol] attribute name to update
    # @param value [Object] the value to assign it
    # @return [Dynamoid::Document] self
    # @since 0.2.0
    def update_attribute(attribute, value)
      write_attribute(attribute, value)
      save
    end

    # Update a model.
    #
    # Runs validation and callbacks. Reloads all attribute values.
    #
    # Accepts mandatory block in order to specify operations which will modify
    # attributes. Supports following operations: +add+, +delete+ and +set+.
    #
    # Operation +add+ just adds a value for numeric attributes and join
    # collections if attribute is a collection (one of +array+, +set+ or
    # +map+).
    #
    #   user.update do |t|
    #     t.add(age: 1, followers_count: 5)
    #     t.add(hobbies: ['skying', 'climbing'])
    #   end
    #
    # Operation +delete+ is applied to collection attribute types and
    # substructs one collection from another.
    #
    #   user.update do |t|
    #     t.delete(hobbies: ['skying'])
    #   end
    #
    # Operation +set+ just changes an attribute value:
    #
    #   user.update do |t|
    #     t.set(age: 21)
    #   end
    #
    # All the operations works like +ADD+, +DELETE+ and +PUT+ actions supported
    # by +AttributeUpdates+
    # {parameter}[https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LegacyConditionalParameters.AttributeUpdates.html]
    # of +UpdateItem+ operation.
    #
    # Can update a model conditionaly:
    #
    #   user.update(if: { age: 20 }) do |t|
    #     t.add(age: 1)
    #   end
    #
    # If a document doesn't meet conditions it raises
    # +Dynamoid::Errors::StaleObjectError+ exception.
    #
    # It will increment the +lock_version+ attribute if a table has the column,
    # but will not check it. Thus, a concurrent +save+ call will never cause an
    # +update!+ to fail, but an +update!+ may cause a concurrent +save+ to
    # fail.
    #
    # @param conditions [Hash] Conditions on model attributes to make a conditional update (optional)
    def update!(conditions = {})
      run_callbacks(:update) do
        options = range_key ? { range_key: Dumping.dump_field(read_attribute(range_key), self.class.attributes[range_key]) } : {}

        begin
          new_attrs = Dynamoid.adapter.update_item(self.class.table_name, hash_key, options.merge(conditions: conditions)) do |t|
            t.add(lock_version: 1) if self.class.attributes[:lock_version]

            if Dynamoid::Config.timestamps
              time_now = DateTime.now.in_time_zone(Time.zone)
              time_now_dumped = Dumping.dump_field(time_now, self.class.attributes[:updated_at])
              t.set(updated_at: time_now_dumped)
            end

            yield t
          end
          load(Undumping.undump_attributes(new_attrs, self.class.attributes))
        rescue Dynamoid::Errors::ConditionalCheckFailedException
          raise Dynamoid::Errors::StaleObjectError.new(self, 'update')
        end
      end
    end

    # Update a model.
    #
    # Runs validation and callbacks. Reloads all attribute values.
    #
    # Accepts mandatory block in order to specify operations which will modify
    # attributes. Supports following operations: +add+, +delete+ and +set+.
    #
    # Operation +add+ just adds a value for numeric attributes and join
    # collections if attribute is a collection (one of +array+, +set+ or
    # +map+).
    #
    #   user.update do |t|
    #     t.add(age: 1, followers_count: 5)
    #     t.add(hobbies: ['skying', 'climbing'])
    #   end
    #
    # Operation +delete+ is applied to collection attribute types and
    # substructs one collection from another.
    #
    #   user.update do |t|
    #     t.delete(hobbies: ['skying'])
    #   end
    #
    # Operation +set+ just changes an attribute value:
    #
    #   user.update do |t|
    #     t.set(age: 21)
    #   end
    #
    # All the operations works like +ADD+, +DELETE+ and +PUT+ actions supported
    # by +AttributeUpdates+
    # {parameter}[https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LegacyConditionalParameters.AttributeUpdates.html]
    # of +UpdateItem+ operation.
    #
    # Can update a model conditionaly:
    #
    #   user.update(if: { age: 20 }) do |t|
    #     t.add(age: 1)
    #   end
    #
    # If a document doesn't meet conditions it just returns +false+. Otherwise it returns +true+.
    #
    # It will increment the +lock_version+ attribute if a table has the column,
    # but will not check it. Thus, a concurrent +save+ call will never cause an
    # +update!+ to fail, but an +update!+ may cause a concurrent +save+ to
    # fail.
    #
    # @param conditions [Hash] Conditions on model attributes to make a conditional update (optional)
    def update(conditions = {}, &block)
      update!(conditions, &block)
      true
    rescue Dynamoid::Errors::StaleObjectError
      false
    end

    # Change numeric attribute value.
    #
    # Initializes attribute to zero if +nil+ and adds the specified value (by
    # default is 1). Only makes sense for number-based attributes.
    #
    #   user.increment(:followers_count)
    #   user.increment(:followers_count, 2)
    #
    # @param attribute [Symbol] attribute name
    # @param by [Numeric] value to add (optional)
    # @return [Dynamoid::Document] self
    def increment(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] += by
      self
    end

    # Change numeric attribute value and save a model.
    #
    # Initializes attribute to zero if +nil+ and adds the specified value (by
    # default is 1). Only makes sense for number-based attributes.
    #
    #   user.increment!(:followers_count)
    #   user.increment!(:followers_count, 2)
    #
    # Returns +true+ if a model was saved and +false+ otherwise.
    #
    # @param attribute [Symbol] attribute name
    # @param by [Numeric] value to add (optional)
    # @return [true|false] whether saved model successfully
    def increment!(attribute, by = 1)
      increment(attribute, by)
      save
    end

    # Change numeric attribute value.
    #
    # Initializes attribute to zero if +nil+ and subtracts the specified value
    # (by default is 1). Only makes sense for number-based attributes.
    #
    #   user.decrement(:followers_count)
    #   user.decrement(:followers_count, 2)
    #
    # @param attribute [Symbol] attribute name
    # @param by [Numeric] value to subtract (optional)
    # @return [Dynamoid::Document] self
    def decrement(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] -= by
      self
    end

    # Change numeric attribute value and save a model.
    #
    # Initializes attribute to zero if +nil+ and subtracts the specified value
    # (by default is 1). Only makes sense for number-based attributes.
    #
    #   user.decrement!(:followers_count)
    #   user.decrement!(:followers_count, 2)
    #
    # Returns +true+ if a model was saved and +false+ otherwise.
    #
    # @param attribute [Symbol] attribute name
    # @param by [Numeric] value to subtract (optional)
    # @return [true|false] whether saved model successfully
    def decrement!(attribute, by = 1)
      decrement(attribute, by)
      save
    end

    # Delete a model.
    #
    # Runs callbacks.
    #
    # Supports optimistic locking with the +lock_version+ attribute and doesn't
    # delete a model if it's already changed.
    #
    # Returns +true+ if deleted successfully and +false+ otherwise.
    #
    # @return [true|false] whether deleted successfully
    # @since 0.2.0
    def destroy
      ret = run_callbacks(:destroy) do
        delete
      end

      @destroyed = true

      ret == false ? false : self
    end

    # Delete a model.
    #
    # Runs callbacks.
    #
    # Supports optimistic locking with the +lock_version+ attribute and doesn't
    # delete a model if it's already changed.
    #
    # Raises +Dynamoid::Errors::RecordNotDestroyed+ exception if model deleting
    # failed.
    def destroy!
      destroy || (raise Dynamoid::Errors::RecordNotDestroyed, self)
    end

    # Delete a model.
    #
    # Supports optimistic locking with the +lock_version+ attribute and doesn't
    # delete a model if it's already changed.
    #
    # Raises +Dynamoid::Errors::StaleObjectError+ exception if cannot delete a
    # model.
    #
    # @since 0.2.0
    def delete
      options = range_key ? { range_key: Dumping.dump_field(read_attribute(range_key), self.class.attributes[range_key]) } : {}

      # Add an optimistic locking check if the lock_version column exists
      if self.class.attributes[:lock_version]
        conditions = { if: {} }
        conditions[:if][:lock_version] =
          if changes[:lock_version].nil?
            lock_version
          else
            changes[:lock_version][0]
          end
        options[:conditions] = conditions
      end

      @destroyed = true

      Dynamoid.adapter.delete(self.class.table_name, hash_key, options)
    rescue Dynamoid::Errors::ConditionalCheckFailedException
      raise Dynamoid::Errors::StaleObjectError.new(self, 'delete')
    end
  end
end
