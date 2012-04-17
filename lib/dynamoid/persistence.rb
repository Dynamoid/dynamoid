require 'securerandom'

# encoding: utf-8
module Dynamoid

  # Persistence is responsible for dumping objects to and marshalling objects from the datastore. It tries to reserialize 
  # values to be of the same type as when they were passed in, based on the fields in the class.
  module Persistence
    extend ActiveSupport::Concern
    
    attr_accessor :new_record
    alias :new_record? :new_record
    
    module ClassMethods
      
      # Returns the name of the table the class is for.
      #
      # @since 0.2.0
      def table_name
        "#{Dynamoid::Config.namespace}_#{self.to_s.downcase.pluralize}"
      end
      
      # Creates a table for a given table name, hash key, and range key.
      #
      # @since 0.2.0
      def create_table(table_name, id = :id, options = {})
        Dynamoid::Adapter.tables << table_name if Dynamoid::Adapter.create_table(table_name, id.to_sym, options)
      end

      def create_table_if_neccessary
        return if table_exists?(table_name)

        opts = {}
        if range_key
          opts[:range_key] = { range_key => attributes[range_key][:type] }
        end

        create_table(table_name, :id, opts)
      end

      # Does a table with this name exist?
      #
      # @since 0.2.0      
      def table_exists?(table_name)
        Dynamoid::Adapter.tables.include?(table_name)
      end
      
      # Undump an object into a hash, converting each type from a string representation of itself into the type specified by the field.
      #
      # @since 0.2.0
      def undump(incoming = nil)
        incoming = (incoming || {}).symbolize_keys
        Hash.new.tap do |hash|
          self.attributes.each do |attribute, options|
            hash[attribute] = undump_field(incoming[attribute], options[:type])
          end
          incoming.each {|attribute, value| hash[attribute] ||= value }
        end
      end

      # Undump a value for a given type. Given a string, it'll determine (based on the type provided) whether to turn it into a 
      # string, integer, float, set, array, datetime, or serialized return value.
      #
      # @since 0.2.0
      def undump_field(value, type)
        return if value.nil? || (value.respond_to?(:empty?) && value.empty?)

        case type
        when :string
          value.to_s
        when :integer
          value.to_i
        when :float
          value.to_f
        when :set, :array
          if value.is_a?(Set) || value.is_a?(Array)
            value
          else
            Set[value]
          end
        when :datetime
          if value.is_a?(Date) || value.is_a?(DateTime) || value.is_a?(Time)
            value
          else
            Time.at(value).to_datetime
          end
        when :serialized
          if value.is_a?(String)
            YAML.load(value)
          else
            value
          end
        end
      end

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
      self.class.create_table_if_neccessary

      @previously_changed = changes

      if new_record?
        run_callbacks(:create) { persist }
      else
        persist
      end

      self
    end

    # Delete this object, but only after running callbacks for it.
    #
    # @since 0.2.0
    def destroy
      run_callbacks(:destroy) do
        self.delete
      end
      self
    end

    # Delete this object from the datastore and all indexes.
    #
    # @since 0.2.0
    def delete
      delete_indexes
      Dynamoid::Adapter.delete(self.class.table_name, self.id)
    end
    
    # Dump this object's attributes into hash form, fit to be persisted into the datastore.
    #
    # @since 0.2.0
    def dump
      Hash.new.tap do |hash|
        self.class.attributes.each do |attribute, options|
          hash[attribute] = dump_field(self.read_attribute(attribute), options[:type])
        end
      end
    end
    
    private

    # Determine how to dump this field. Given a value, it'll determine how to turn it into a value that can be 
    # persisted into the datastore.
    #
    # @since 0.2.0
    def dump_field(value, type)
      return if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      case type
      when :string
        value.to_s
      when :integer
        value.to_i
      when :float
        value.to_f
      when :set, :array
        if value.is_a?(Set) || value.is_a?(Array)
          value
        else
          Set[value]
        end
      when :datetime
        value.to_time.to_f
      when :serialized
        value.to_yaml
      end
    end

    # Persist the object into the datastore. Assign it an id first if it doesn't have one; then afterwards, 
    # save its indexes.
    #
    # @since 0.2.0
    def persist
      run_callbacks(:save) do
        self.id = SecureRandom.uuid if self.id.nil? || self.id.blank?
        Dynamoid::Adapter.write(self.class.table_name, self.dump)
        save_indexes
        @new_record = false
        true
      end
    end
        
  end
  
end
