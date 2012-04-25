# encoding: utf-8
module Dynamoid #:nodoc:

  # All fields on a Dynamoid::Document must be explicitly defined -- if you have fields in the database that are not 
  # specified with field, then they will be ignored.
  module Fields
    extend ActiveSupport::Concern

    # Initialize the attributes we know the class has, in addition to our magic attributes: id, created_at, and updated_at.
    included do
      class_attribute :attributes
      class_attribute :range_key

      self.attributes = {}

      field :id
      field :created_at, :datetime
      field :updated_at, :datetime
    end
    
    module ClassMethods
      
      # Specify a field for a document. Its type determines how it is coerced when read in and out of the datastore: 
      # default is string, but you can also specify :integer, :float, :set, :array, :datetime, and :serialized.
      #
      # @param [Symbol] name the name of the field
      # @param [Symbol] type the type of the field (one of :integer, :float, :set, :array, :datetime, or :serialized)
      # @param [Hash] options any additional options for the field
      #
      # @since 0.2.0
      def field(name, type = :string, options = {})
        named = name.to_s
        self.attributes[name] = {:type => type}.merge(options)

        define_method(named) { read_attribute(named) }
        define_method("#{named}?") { !read_attribute(named).nil? }
        define_method("#{named}=") {|value| write_attribute(named, value) }

        respond_to?(:define_attribute_method) ? define_attribute_method(name) : define_attribute_methods([name])
      end

      def range(name, type = :string)
        field(name, type)
        self.range_key = name
      end
    end
    
    # You can access the attributes of an object directly on its attributes method, which is by default an empty hash.
    attr_accessor :attributes
    alias :raw_attributes :attributes

    # Write an attribute on the object. Also marks the previous value as dirty.
    #
    # @param [Symbol] name the name of the field
    # @param [Object] value the value to assign to that field
    #
    # @since 0.2.0
    def write_attribute(name, value)
      if (size = value.to_s.size) > MAX_ITEM_SIZE
        Dynamoid.logger.warn "DynamoDB can't store items larger than #{MAX_ITEM_SIZE} and the #{name} field has a length of #{size}."
      end

      attribute_will_change!(name) unless self.read_attribute(name) == value

      if association = @associations[name]
        association.reset
      end

      attributes[name.to_sym] = value
    end
    alias :[]= :write_attribute

    # Read an attribute from an object.
    #
    # @param [Symbol] name the name of the field
    #
    # @since 0.2.0
    def read_attribute(name)
      attributes[name.to_sym]
    end
    alias :[] :read_attribute

    # Updates multiple attibutes at once, saving the object once the updates are complete.
    #
    # @param [Hash] attributes a hash of attributes to update
    #
    # @since 0.2.0
    def update_attributes(attributes)
      attributes.each {|attribute, value| self.write_attribute(attribute, value)}
      save
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
    
    private
    
    # Automatically called during the created callback to set the created_at time.
    #
    # @since 0.2.0
    def set_created_at
      self.created_at = DateTime.now
    end

    # Automatically called during the save callback to set the updated_at time.
    #
    # @since 0.2.0    
    def set_updated_at
      self.updated_at = DateTime.now
    end
    
  end
  
end
