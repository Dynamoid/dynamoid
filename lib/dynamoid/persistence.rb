# frozen_string_literal: true

require 'bigdecimal'
require 'securerandom'
require 'yaml'

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
        table_base_name = options[:name] || base_class.name.split('::').last
                                                      .downcase.pluralize

        @table_name ||= [Dynamoid::Config.namespace.to_s, table_base_name].reject(&:empty?).join('_')
      end

      # Creates a table.
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
          write_capacity: write_capacity,
          read_capacity: read_capacity,
          range_key: range_key_hash,
          hash_key_type: PrimaryKeyTypeMapping.dynamodb_type(attributes[hash_key][:type], attributes[hash_key]),
          local_secondary_indexes: local_secondary_indexes.values,
          global_secondary_indexes: global_secondary_indexes.values
        }.merge(options)

        Dynamoid.adapter.create_table(options[:table_name], options[:id], options)
      end

      # Deletes the table for the model
      def delete_table
        Dynamoid.adapter.delete_table(table_name)
      end

      def from_database(attrs = {})
        clazz = attrs[:type] ? obj = attrs[:type].constantize : self
        attrs_undumped = Undumping.undump_attributes(attrs, clazz.attributes)
        clazz.new(attrs_undumped).tap { |r| r.new_record = false }
      end

      # Creates several models at once.
      # Neither callbacks nor validations run.
      # It works efficiently because of using BatchWriteItem.
      #
      # Returns array of models
      #
      # Uses backoff specified by `Dynamoid::Config.backoff` config option
      #
      # @param [Array<Hash>] items
      #
      # @example
      #   User.import([{ name: 'a' }, { name: 'b' }])
      def import(objects)
        documents = objects.map do |attrs|
          attrs = attrs.symbolize_keys

          if Dynamoid::Config.timestamps
            time_now = DateTime.now.in_time_zone(Time.zone)
            attrs[:created_at] ||= time_now
            attrs[:updated_at] ||= time_now
          end

          build(attrs).tap do |item|
            item.hash_key = SecureRandom.uuid if item.hash_key.blank?
          end
        end

        if Dynamoid.config.backoff
          backoff = nil

          array = documents.map do |d|
            Dumping.dump_attributes(d.attributes, attributes)
          end

          Dynamoid.adapter.batch_write_item(table_name, array) do |has_unprocessed_items|
            if has_unprocessed_items
              backoff ||= Dynamoid.config.build_backoff
              backoff.call
            else
              backoff = nil
            end
          end
        else
          array = documents.map do |d|
            Dumping.dump_attributes(d.attributes, attributes)
          end

          Dynamoid.adapter.batch_write_item(table_name, array)
        end

        documents.each { |d| d.new_record = false }
        documents
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
      self.class.create_table

      if new_record?
        conditions = { unless_exists: [self.class.hash_key] }
        conditions[:unless_exists] << range_key if range_key

        run_callbacks(:create) { persist(conditions) }
      else
        persist
      end
    end

    # Updates multiple attibutes at once, saving the object once the updates are complete.
    #
    # @param [Hash] attributes a hash of attributes to update
    #
    # @since 0.2.0
    def update_attributes(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) } unless attributes.nil? || attributes.empty?
      save
    end

    # Updates multiple attibutes at once, saving the object once the updates are complete.
    # Raises a Dynamoid::Errors::DocumentNotValid exception if there is vaidation and it fails.
    #
    # @param [Hash] attributes a hash of attributes to update
    def update_attributes!(attributes)
      attributes.each { |attribute, value| write_attribute(attribute, value) } unless attributes.nil? || attributes.empty?
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

    private

    # Persist the object into the datastore. Assign it an id first if it doesn't have one.
    #
    # @since 0.2.0
    def persist(conditions = nil)
      run_callbacks(:save) do
        self.hash_key = SecureRandom.uuid if hash_key.blank?

        # Add an exists check to prevent overwriting existing records with new ones
        if new_record?
          conditions ||= {}
          (conditions[:unless_exists] ||= []) << self.class.hash_key
        end

        # Add an optimistic locking check if the lock_version column exists
        if self.class.attributes[:lock_version]
          conditions ||= {}
          self.lock_version = (lock_version || 0) + 1
          # Uses the original lock_version value from ActiveModel::Dirty in case user changed lock_version manually
          (conditions[:if] ||= {})[:lock_version] = changes[:lock_version][0] if changes[:lock_version][0]
        end

        attributes_dumped = Dumping.dump_attributes(attributes, self.class.attributes)

        begin
          Dynamoid.adapter.write(self.class.table_name, attributes_dumped, conditions)
          @new_record = false
          true
        rescue Dynamoid::Errors::ConditionalCheckFailedException => e
          if new_record?
            raise Dynamoid::Errors::RecordNotUnique.new(e, self)
          else
            raise Dynamoid::Errors::StaleObjectError.new(self, 'persist')
          end
        end
      end
    end
  end
end
