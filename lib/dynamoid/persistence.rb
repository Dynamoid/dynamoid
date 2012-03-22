require 'securerandom'

# encoding: utf-8
module Dynamoid #:nodoc:

  # This module saves things!
  module Persistence
    extend ActiveSupport::Concern
    
    attr_accessor :new_record
    alias :new_record? :new_record
    
    module ClassMethods
      def table_name
        "#{Dynamoid::Config.namespace}_#{self.to_s.downcase.pluralize}"
      end
      
      def create_table(table_name, id = :id, options = {})
        Dynamoid::Adapter.tables << table_name if Dynamoid::Adapter.create_table(table_name, id.to_sym, options)
      end
      
      def table_exists?(table_name)
        Dynamoid::Adapter.tables.include?(table_name)
      end
      
      def undump(incoming = {})
        incoming.symbolize_keys!
        Hash.new.tap do |hash|
          self.attributes.each do |attribute, options|
            hash[attribute] = undump_field(incoming[attribute], options[:type])
          end
        end
      end

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
    
    included do
      self.create_table(self.table_name) unless self.table_exists?(self.table_name)
    end
    
    def persisted?
      !new_record?
    end
    
    def save
      if self.new_record?
        run_callbacks(:create) do
          run_callbacks(:save) do
            persist
          end
        end
      else
        run_callbacks(:save) do
          persist
        end
      end
      self
    end

    def destroy
      run_callbacks(:destroy) do
        self.delete
      end
      self
    end

    def delete
      delete_indexes
      Dynamoid::Adapter.delete(self.class.table_name, self.id)
    end
    
    def dump
      Hash.new.tap do |hash|
        self.class.attributes.each do |attribute, options|
          hash[attribute] = dump_field(self.read_attribute(attribute), options[:type])
        end
      end
    end
    
    private

    def dump_field value, type
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

    def persist
      self.id = SecureRandom.uuid if self.id.nil? || self.id.blank?
      Dynamoid::Adapter.write(self.class.table_name, self.dump)
      save_indexes
      @new_record = false
    end
        
  end
  
end
