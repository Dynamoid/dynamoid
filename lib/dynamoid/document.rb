# encoding: utf-8
module Dynamoid #:nodoc:

  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components
    
    included do
      class_attribute :options
      self.options = {}
      
      Dynamoid::Config.included_models << self
    end
    
    module ClassMethods
      # Set up table options, including naming it whatever you want, setting the id key, and manually overriding read and 
      # write capacity.
      # 
      # @param [Hash] options options to pass for this table
      # @option options [Symbol] :name the name for the table; this still gets namespaced
      # @option options [Symbol] :id id column for the table
      # @option options [Integer] :read_capacity set the read capacity for the table; does not work on existing tables
      # @option options [Integer] :write_capacity set the write capacity for the table; does not work on existing tables
      #
      # @since 0.4.0
      def table(options = {})
        self.options = options
      end
      
      # Returns the read_capacity for this table.
      #
      # @since 0.4.0
      def read_capacity
        options[:read_capacity] || Dynamoid::Config.read_capacity
      end
      
      # Returns the write_capacity for this table.
      #
      # @since 0.4.0
      def write_capacity
        options[:write_capacity] || Dynamoid::Config.write_capacity
      end
      
      # Returns the id field for this class.
      #
      # @since 0.4.0
      def hash_key
        options[:key] || :id
      end

      # Initialize a new object and immediately save it to the database.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create(attrs = {})
        new(attrs).tap(&:save)
      end

      # Initialize a new object and immediately save it to the database. Raise an exception if persistence failed.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create!(attrs = {})
        new(attrs).tap(&:save!)
      end
      
      # Initialize a new object.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the new document
      #
      # @since 0.2.0
      def build(attrs = {})
        new(attrs)
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
      run_callbacks :initialize do
        self.class.send(:field, self.class.hash_key) unless self.respond_to?(self.class.hash_key)

        @new_record = true
        @attributes ||= {}
        @associations ||= {}

        self.class.undump(attrs).each {|key, value| send "#{key}=", value }
      end
    end

    # An object is equal to another object if their ids are equal.
    #
    # @since 0.2.0
    def ==(other)
      return false if other.nil?
      other.respond_to?(:hash_key) && other.hash_key == self.hash_key
    end

    # Reload an object from the database -- if you suspect the object has changed in the datastore and you need those
    # changes to be reflected immediately, you would call this method.
    #
    # @return [Dynamoid::Document] the document this method was called on
    #
    # @since 0.2.0
    def reload
      self.attributes = self.class.find(self.hash_key).attributes
      @associations.values.each(&:reset)
      self
    end

    # Return an object's hash key, regardless of what it might be called to the object.
    #
    # @since 0.4.0
    def hash_key
      self.send(self.class.hash_key)
    end

    # Assign an object's hash key, regardless of what it might be called to the object.
    #
    # @since 0.4.0
    def hash_key=(key)
      self.send("#{self.class.hash_key}=".to_sym, key)
    end
  end
  
end
