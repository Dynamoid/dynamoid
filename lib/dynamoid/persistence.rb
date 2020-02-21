# frozen_string_literal: true

require 'bigdecimal'
require 'securerandom'
require 'yaml'

require 'dynamoid/persistence/import'
require 'dynamoid/persistence/update_fields'
require 'dynamoid/persistence/upsert'
require 'dynamoid/persistence/save'

# encoding: utf-8
module Dynamoid
  # Persistence is responsible for dumping objects to and marshalling objects from the datastore. It tries to reserialize
  # values to be of the same type as when they were passed in, based on the fields in the class.
  module Persistence
    extend ActiveSupport::Concern

    attr_accessor :new_record
    alias new_record? new_record

    UNIX_EPOCH_DATE = Date.new(1970, 1, 1).freeze

    module ClassMethods
      def table_name
        table_base_name = options[:name] || base_class.name.split('::').last.downcase.pluralize

        @table_name ||= [Dynamoid::Config.namespace.to_s, table_base_name].reject(&:empty?).join('_')
      end

      # Create a table.
      #
      # @param [Hash] options options to pass for table creation
      # @option options [Symbol] :id the id field for the table
      # @option options [Symbol] :table_name the actual name for the table
      # @option options [Integer] :read_capacity set the read capacity for the table; does not work on existing tables
      # @option options [Integer] :write_capacity set the write capacity for the table; does not work on existing tables
      # @option options [Hash] {range_key => :type} a hash of the name of the range key and a symbol of its type
      # @option options [Symbol] :hash_key_type the dynamo type of the hash key (:string or :number)
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

      # Deletes the table for the model
      def delete_table
        Dynamoid.adapter.delete_table(table_name)
      end

      def from_database(attrs = {})
        klass = choose_right_class(attrs)
        attrs_undumped = Undumping.undump_attributes(attrs, klass.attributes)
        klass.new(attrs_undumped).tap { |r| r.new_record = false }
      end

      # Create several models at once.
      #
      # Neither callbacks nor validations run.
      # It works efficiently because of using `BatchWriteItem` API call.
      # Return array of models.
      # Uses backoff specified by `Dynamoid::Config.backoff` config option
      #
      # @param [Array<Hash>] array_of_attributes
      #
      # @example
      #   User.import([{ name: 'a' }, { name: 'b' }])
      def import(array_of_attributes)
        Import.call(self, array_of_attributes)
      end

      # Create a model.
      #
      # Initializes a new object and immediately saves it to the database.
      # Validates model and runs callbacks: before_create, before_save, after_save and after_create.
      # Accepts both Hash and Array of Hashes and can create several models.
      #
      # @param [Hash|Array[Hash]] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create(attrs = {})
        if attrs.is_a?(Array)
          attrs.map { |attr| create(attr) }
        else
          build(attrs).tap(&:save)
        end
      end

      # Create new model.
      #
      # Initializes a new object and immediately saves it to the database.
      # Raises an exception if validation failed.
      # Accepts both Hash and Array of Hashes and can create several models.
      #
      # @param [Hash|Array[Hash]] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create!(attrs = {})
        if attrs.is_a?(Array)
          attrs.map { |attr| create!(attr) }
        else
          build(attrs).tap(&:save!)
        end
      end

      # Update document with provided attributes.
      #
      # Instantiates document and saves changes.
      # Runs validations and callbacks.
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key, optional
      # @param [Hash] attributes
      #
      # @return [Dynamoid::Doument] updated document
      #
      # @example Update document
      #   Post.update(101, title: 'New title')
      def update(hash_key, range_key_value = nil, attrs)
        model = find(hash_key, range_key: range_key_value, consistent_read: true)
        model.update_attributes(attrs)
        model
      end

      # Update document with provided attributes.
      #
      # Instantiates document and saves changes.
      # Runs validations and callbacks. Raises Dynamoid::Errors::DocumentNotValid exception if validation fails.
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key, optional
      # @param [Hash] attributes
      #
      # @return [Dynamoid::Doument] updated document
      #
      # @example Update document
      #   Post.update!(101, title: 'New title')
      def update!(hash_key, range_key_value = nil, attrs)
        model = find(hash_key, range_key: range_key_value, consistent_read: true)
        model.update_attributes!(attrs)
        model
      end

      # Update document.
      #
      # Uses efficient low-level `UpdateItem` API call.
      # Changes attibutes and loads new document version with one API call.
      # Doesn't run validations and callbacks. Can make conditional update.
      # If a document doesn't exist or specified conditions failed - returns `nil`
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key (optional)
      # @param [Hash] attributes
      # @param [Hash] conditions
      #
      # @return [Dynamoid::Document|nil] updated document
      #
      # @example Update document
      #   Post.update_fields(101, read: true)
      #
      # @example Update document with condition
      #   Post.update_fields(101, { title: 'New title' }, if: { version: 1 })
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

      # Update existing document or create new one.
      #
      # Similar to `.update_fields`.
      # The only diffirence is - it creates new document in case the document doesn't exist.
      #
      # Uses efficient low-level `UpdateItem` API call.
      # Changes attibutes and loads new document version with one API call.
      # Doesn't run validations and callbacks. Can make conditional update.
      # If specified conditions failed - returns `nil`.
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key (optional)
      # @param [Hash] attributes
      # @param [Hash] conditions
      #
      # @return [Dynamoid::Document/nil] updated document
      #
      # @example Update document
      #   Post.upsert(101, title: 'New title')
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

      # Increase numeric field by specified value.
      #
      # Can update several fields at once.
      # Uses efficient low-level `UpdateItem` API call.
      #
      # @param [Scalar value] hash_key_value partition key
      # @param [Scalar value] range_key_value sort key (optional)
      # @param [Hash] counters value to increase by
      #
      # @return [Dynamoid::Document/nil] updated document
      #
      # @example Update document
      #   Post.inc(101, views_counter: 2, downloads: 10)
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

    # Set updated_at and any passed in field to current DateTime. Useful for things like last_login_at, etc.
    #
    def touch(name = nil)
      now = DateTime.now
      self.updated_at = now
      attributes[name] = now if name
      save
    end

    # Is this object persisted in the datastore? Required for some ActiveModel integration stuff.
    #
    # @since 0.2.0
    def persisted?
      !new_record?
    end

    # Run the callbacks and then persist this object in the datastore.
    #
    # @since 0.2.0
    def save(_options = {})
      self.class.create_table(sync: true)

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

    # Updates multiple attributes at once, saving the object once the updates are complete.
    #
    # @param [Hash] attributes a hash of attributes to update
    #
    # @since 0.2.0
    def update_attributes(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) }
      save
    end

    # Updates multiple attributes at once, saving the object once the updates are complete.
    # Raises a Dynamoid::Errors::DocumentNotValid exception if there is vaidation and it fails.
    #
    # @param [Hash] attributes a hash of attributes to update
    def update_attributes!(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) }
      save!
    end

    # Update a single attribute, saving the object afterwards.
    #
    # @param [Symbol] attribute the attribute to update
    # @param [Object] value the value to assign it
    #
    # @since 0.2.0
    def update_attribute(attribute, value)
      write_attribute(attribute, value)
      save
    end

    #
    # update!() will increment the lock_version if the table has the column, but will not check it. Thus, a concurrent save will
    # never cause an update! to fail, but an update! may cause a concurrent save to fail.
    #
    #
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

    def update(conditions = {}, &block)
      update!(conditions, &block)
      true
    rescue Dynamoid::Errors::StaleObjectError
      false
    end

    # Initializes attribute to zero if nil and adds the value passed as by (default is 1).
    # Only makes sense for number-based attributes. Returns self.
    def increment(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] += by
      self
    end

    # Wrapper around increment that saves the record.
    # Returns true if the record could be saved.
    def increment!(attribute, by = 1)
      increment(attribute, by)
      save
    end

    # Initializes attribute to zero if nil and subtracts the value passed as by (default is 1).
    # Only makes sense for number-based attributes. Returns self.
    def decrement(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] -= by
      self
    end

    # Wrapper around decrement that saves the record.
    # Returns true if the record could be saved.
    def decrement!(attribute, by = 1)
      decrement(attribute, by)
      save
    end

    # Delete this object, but only after running callbacks for it.
    #
    # @since 0.2.0
    def destroy
      ret = run_callbacks(:destroy) do
        delete
      end
      ret == false ? false : self
    end

    def destroy!
      destroy || (raise Dynamoid::Errors::RecordNotDestroyed, self)
    end

    # Delete this object from the datastore.
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
      Dynamoid.adapter.delete(self.class.table_name, hash_key, options)
    rescue Dynamoid::Errors::ConditionalCheckFailedException
      raise Dynamoid::Errors::StaleObjectError.new(self, 'delete')
    end
  end
end
