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
    alias :new_record? :new_record

    UNIX_EPOCH_DATE = Date.new(1970, 1, 1).freeze

    module ClassMethods

      def table_name
        table_base_name = options[:name] || base_class.name.split('::').last
          .downcase.pluralize

        @table_name ||= [Dynamoid::Config.namespace.to_s, table_base_name].reject(&:empty?).join("_")
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
        if self.range_key
          range_key_hash = { range_key => dynamo_type(attributes[range_key][:type]) }
        else
          range_key_hash = nil
        end
        options = {
          :id => self.hash_key,
          :table_name => self.table_name,
          :write_capacity => self.write_capacity,
          :read_capacity => self.read_capacity,
          :range_key => range_key_hash,
          :hash_key_type => dynamo_type(attributes[self.hash_key][:type]),
          :local_secondary_indexes => self.local_secondary_indexes.values,
          :global_secondary_indexes => self.global_secondary_indexes.values
        }.merge(options)

        Dynamoid.adapter.create_table(options[:table_name], options[:id], options)
      end

      # Deletes the table for the model
      def delete_table
        Dynamoid.adapter.delete_table(self.table_name)
      end

      def from_database(attrs = {})
        clazz = attrs[:type] ? obj = attrs[:type].constantize : self
        clazz.new(attrs).tap { |r| r.new_record = false }
      end

      # Undump an object into a hash, converting each type from a string representation of itself into the type specified by the field.
      #
      # @since 0.2.0
      def undump(incoming = nil)
        incoming = (incoming || {}).symbolize_keys
        Hash.new.tap do |hash|
          self.attributes.each do |attribute, options|
            if incoming.has_key?(attribute)
              hash[attribute] = undump_field(incoming[attribute], options)
            elsif options.has_key?(:default)
              hash[attribute] = evaluate_default_value(options[:default])
            else
              hash[attribute] = nil
            end
          end
          incoming.each {|attribute, value| hash[attribute] = value unless hash.has_key? attribute }
        end
      end

      # Undump a string value for a given type.
      #
      # @since 0.2.0
      def undump_field(value, options)
        if (field_class = options[:type]).is_a?(Class)
          raise 'Dynamoid class-type fields do not support default values' if options[:default]

          if field_class.respond_to?(:dynamoid_load)
            field_class.dynamoid_load(value)
          end
        elsif options[:type] == :serialized
          if value.is_a?(String)
            options[:serializer] ? options[:serializer].load(value) : YAML.load(value)
          else
            value
          end
        else
          unless value.nil?
            case options[:type]
              when :string
                value.to_s
              when :integer
                Integer(value)
              when :number
                BigDecimal.new(value.to_s)
              when :array
                value.to_a
              when :raw
                if value.is_a?(Hash)
                  undump_hash(value)
                else
                  value
                end
              when :set
                Set.new(value)
              when :datetime
                if value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(Time)
                  value
                else
                  case Dynamoid::Config.application_timezone
                    when :utc
                      ActiveSupport::TimeZone['UTC'].at(value).to_datetime
                    when :local
                      Time.at(value).to_datetime
                    when String
                      ActiveSupport::TimeZone[Dynamoid::Config.application_timezone].at(value).to_datetime
                  end
                end
              when :date
                if value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(Time)
                  value.to_date
                else
                  UNIX_EPOCH_DATE + value.to_i
                end
              when :boolean
                # persisted as 't', but because undump is called during initialize it can come in as true
                if value == 't' || value == true
                  true
                elsif value == 'f' || value == false
                  false
                else
                  raise ArgumentError, "Boolean column neither true nor false"
                end
              else
                raise ArgumentError, "Unknown type #{options[:type]}"
            end
          end
        end
      end

      def dump_field(value, options)
        if (field_class = options[:type]).is_a?(Class)
          if value.respond_to?(:dynamoid_dump)
            value.dynamoid_dump
          elsif field_class.respond_to?(:dynamoid_dump)
            field_class.dynamoid_dump(value)
          else
            raise ArgumentError, "Neither #{field_class} nor #{value} support serialization for Dynamoid."
          end
        else
          case options[:type]
            when :string
              !value.nil? ? value.to_s : nil
            when :integer
              !value.nil? ? Integer(value) : nil
            when :number
              !value.nil? ? value : nil
            when :set
              !value.nil? ? Set.new(value) : nil
            when :array
              !value.nil? ? value : nil
            when :datetime
              !value.nil? ? value.to_time.to_f : nil
            when :date
              !value.nil? ? (value.to_date - UNIX_EPOCH_DATE).to_i : nil
            when :serialized
              options[:serializer] ? options[:serializer].dump(value) : value.to_yaml
            when :raw
              !value.nil? ? value : nil
            when :boolean
              !value.nil? ? value.to_s[0] : nil
            else
              raise ArgumentError, "Unknown type #{options[:type]}"
          end
        end
      end

      def dynamo_type(type)
        if type.is_a?(Class)
          type.respond_to?(:dynamoid_field_type) ? type.dynamoid_field_type : :string
        else
          case type
            when :integer, :number, :datetime, :date
              :number
            when :string, :serialized
              :string
            else
              raise 'unknown type'
          end
        end
      end

      def import(objects)
        documents = objects.map { |attrs|
          self.build(attrs).tap { |item|
            item.hash_key = SecureRandom.uuid if item.hash_key.blank?
          }
        }

        documents.each_slice(25) do |docs|
          Dynamoid.adapter.batch_write_item(self.table_name, docs.map(&:dump))
        end

        documents.each { |d| d.new_record = false }
        documents
      end

      private

      def undump_hash(hash)
        {}.tap do |h|
          hash.each { |key, value| h[key.to_sym] = undump_hash_value(value) }
        end
      end

      def undump_hash_value(val)
        case val
        when BigDecimal
          if Dynamoid::Config.convert_big_decimal
            val.to_f
          else
            val
          end
        when Hash
          undump_hash(val)
        when Array
          val.map { |v| undump_hash_value(v) }
        else
          val
        end
      end

      # Evaluates the default value given, this is used by undump
      # when determining the value of the default given for a field options.
      #
      # @param [Object] :value the attribute's default value
      def evaluate_default_value(val)
        if val.respond_to?(:call)
          val.call
        elsif val.duplicable?
          val.dup
        else
          val
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
    def save(options = {})
      self.class.create_table

      if new_record?
        conditions = { :unless_exists => [self.class.hash_key]}
        conditions[:unless_exists] << range_key if(range_key)

        run_callbacks(:create) { persist(conditions) }
      else
        persist
      end
    end

    #
    # update!() will increment the lock_version if the table has the column, but will not check it. Thus, a concurrent save will
    # never cause an update! to fail, but an update! may cause a concurrent save to fail.
    #
    #
    def update!(conditions = {}, &block)
      run_callbacks(:update) do
        options = range_key ? {:range_key => dump_field(self.read_attribute(range_key), self.class.attributes[range_key])} : {}

        begin
          new_attrs = Dynamoid.adapter.update_item(self.class.table_name, self.hash_key, options.merge(:conditions => conditions)) do |t|
            if(self.class.attributes[:lock_version])
              t.add(lock_version: 1)
            end

            yield t
          end
          load(new_attrs)
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

    # Delete this object, but only after running callbacks for it.
    #
    # @since 0.2.0
    def destroy
      ret = run_callbacks(:destroy) do
        self.delete
      end
      (ret == false) ? false : self
    end

    def destroy!
      destroy || raise(Dynamoid::Errors::RecordNotDestroyed.new(self))
    end

    # Delete this object from the datastore.
    #
    # @since 0.2.0
    def delete
      options = range_key ? {:range_key => dump_field(self.read_attribute(range_key), self.class.attributes[range_key])} : {}

      # Add an optimistic locking check if the lock_version column exists
      if(self.class.attributes[:lock_version])
        conditions = {:if => {}}
        conditions[:if][:lock_version] =
          if changes[:lock_version].nil?
            self.lock_version
          else
            changes[:lock_version][0]
          end
        options[:conditions] = conditions
      end
      Dynamoid.adapter.delete(self.class.table_name, self.hash_key, options)
    rescue Dynamoid::Errors::ConditionalCheckFailedException
      raise Dynamoid::Errors::StaleObjectError.new(self, 'delete')
    end

    # Dump this object's attributes into hash form, fit to be persisted into the datastore.
    #
    # @since 0.2.0
    def dump
      Hash.new.tap do |hash|
        self.class.attributes.each do |attribute, options|
          hash[attribute] = dump_field(self.read_attribute(attribute), options)
        end
      end
    end

    private

    # Determine how to dump this field. Given a value, it'll determine how to turn it into a value that can be
    # persisted into the datastore.
    #
    # @since 0.2.0
    def dump_field(value, options)
      self.class.dump_field(value, options)
    end

    # Persist the object into the datastore. Assign it an id first if it doesn't have one.
    #
    # @since 0.2.0
    def persist(conditions = nil)
      run_callbacks(:save) do
        self.hash_key = SecureRandom.uuid if self.hash_key.blank?

        # Add an exists check to prevent overwriting existing records with new ones
        if(new_record?)
          conditions ||= {}
          (conditions[:unless_exists] ||= []) << self.class.hash_key
        end

        # Add an optimistic locking check if the lock_version column exists
        if(self.class.attributes[:lock_version])
          conditions ||= {}
          self.lock_version = (lock_version || 0) + 1
          # Uses the original lock_version value from ActiveModel::Dirty in case user changed lock_version manually
          (conditions[:if] ||= {})[:lock_version] = changes[:lock_version][0] if(changes[:lock_version][0])
        end

        begin
          Dynamoid.adapter.write(self.class.table_name, self.dump, conditions)
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
