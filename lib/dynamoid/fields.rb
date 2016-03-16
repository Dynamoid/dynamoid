# encoding: utf-8
module Dynamoid #:nodoc:
  # All fields on a Dynamoid::Document must be explicitly defined -- if you have fields in the database that are not
  # specified with field, then they will be ignored.
  module Fields
    extend ActiveSupport::Concern

    PERMITTED_KEY_TYPES = [
      :number,
      :integer,
      :string,
      :datetime
    ]

    # Initialize the attributes we know the class has, in addition to our magic attributes: id, created_at, and updated_at.
    included do
      class_attribute :attributes
      class_attribute :range_key

      self.attributes = {}
      field :created_at, :datetime
      field :updated_at, :datetime

      field :id #Default primary key
    end

    module ClassMethods

      # Specify a field for a document.
      #
      # Its type determines how it is coerced when read in and out of the datastore.
      # You can specify :integer, :number, :set, :array, :datetime, and :serialized,
      # or specify a class that defines a serialization strategy.
      #
      # If you specify a class for field type, Dynamoid will serialize using
      # `dynamoid_dump` or `dump` methods, and load using `dynamoid_load` or `load` methods.
      #
      # Default field type is :string.
      #
      # @param [Symbol] name the name of the field
      # @param [Symbol] type the type of the field (refer to method description for details)
      # @param [Hash] options any additional options for the field
      #
      # @since 0.2.0
      def field(name, type = :string, options = {})
        named = name.to_s
        if type == :float
          Dynamoid.logger.warn("Field type :float, which you declared for '#{name}', is deprecated in favor of :number.")
          type = :number
        end
        self.attributes = attributes.merge(name => {:type => type}.merge(options))

        define_method(named) { read_attribute(named) }
        define_method("#{named}?") do
          value = read_attribute(named)
          case value
          when true        then true
          when false, nil  then false
          else
            !value.nil?
          end
        end
        define_method("#{named}=") {|value| write_attribute(named, value) }
      end

      def range(name, type = :string)
        field(name, type)
        self.range_key = name
      end

      def table(options)
        #a default 'id' column is created when Dynamoid::Document is included
        unless(attributes.has_key? hash_key)
          remove_field :id
          field(hash_key)
        end
      end

      def remove_field(field)
        field = field.to_sym
        attributes.delete(field) or raise "No such field"
        remove_method field
        remove_method :"#{field}="
        remove_method :"#{field}?"
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
      attributes.each {|attribute, value| self.write_attribute(attribute, value)} unless attributes.nil? || attributes.empty?
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
      self.created_at = DateTime.now if Dynamoid::Config.timestamps
    end

    # Automatically called during the save callback to set the updated_at time.
    #
    # @since 0.2.0
    def set_updated_at
      self.updated_at = DateTime.now if Dynamoid::Config.timestamps
    end

    def set_type
      self.type ||= self.class.to_s if self.class.attributes[:type]
    end

  end

end
