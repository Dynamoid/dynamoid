# encoding: utf-8
module Dynamoid #:nodoc:

  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components
    
    included do
      Dynamoid::Config.included_models << self
    end
    
    module ClassMethods

      # Initialize a new object and immediately save it to the database.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create(attrs = {})
        obj = self.new(attrs)
        obj.run_callbacks(:create) do
          obj.save
        end
        obj
      end

      # Initialize a new object and immediately save it to the database. Raise an exception if persistence failed.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create!(attrs = {})
        obj = self.new(attrs)
        obj.run_callbacks(:create) do
          obj.save!
        end
        obj
      end
      
      # Initialize a new object.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the new document
      #
      # @since 0.2.0
      def build(attrs = {})
        self.new(attrs)
      end

      # Does this object exist?
      #
      # @param [String] id the id of the object
      #
      # @return [Boolean] true/false
      #
      # @since 0.2.0
      def exists?(id)
        !! find(id)
      end
    end

    # Initialize a new object.
    #
    # @param [Hash] attrs Attributes with which to create the object.
    #
    # @return [Dynamoid::Document] the new document
    #
    # @since 0.2.0    
    def initialize(attrs = {})
      @new_record = true
      @attributes ||= {}
      incoming_attributes = self.class.undump(attrs)

      self.class.attributes.keys.each do |attribute|
        send "#{attribute}=", incoming_attributes[attribute]
      end
    end

    # An object is equal to another object if their ids are equal.
    #
    # @since 0.2.0    
    def ==(other)
      return false if other.nil?
      other.respond_to?(:id) && other.id == self.id
    end

    # Reload an object from the database -- if you suspect the object has changed in the datastore and you need those 
    # changes to be reflected immediately, you would call this method.
    #
    # @return [Dynamoid::Document] the document this method was called on
    #
    # @since 0.2.0        
    def reload
      self.attributes = self.class.find(self.id).attributes
      self
    end
  end
  
end
