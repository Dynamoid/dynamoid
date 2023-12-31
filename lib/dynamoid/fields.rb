# frozen_string_literal: true

require 'dynamoid/fields/declare'

module Dynamoid
  # All fields on a Dynamoid::Document must be explicitly defined -- if you have fields in the database that are not
  # specified with field, then they will be ignored.
  module Fields
    extend ActiveSupport::Concern

    # Initialize the attributes we know the class has, in addition to our magic attributes: id, created_at, and updated_at.
    included do
      class_attribute :attributes, instance_accessor: false
      class_attribute :range_key

      self.attributes = {}

      # Timestamp fields could be disabled later in `table` method call.
      # So let's declare them here and remove them later if it will be necessary
      field :created_at, :datetime if Dynamoid::Config.timestamps
      field :updated_at, :datetime if Dynamoid::Config.timestamps

      field :id # Default primary key
    end

    module ClassMethods
      # Specify a field for a document.
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     field :last_name
      #     field :age, :integer
      #     field :last_sign_in, :datetime
      #   end
      #
      # Its type determines how it is coerced when read in and out of the
      # data store. You can specify +string+, +integer+, +number+, +set+, +array+,
      # +map+, +datetime+, +date+, +serialized+, +raw+, +boolean+ and +binary+
      # or specify a class that defines a serialization strategy.
      #
      # By default field type is +string+.
      #
      # Set can store elements of the same type only (it's a limitation of
      # DynamoDB itself). If a set should store elements only of some particular
      # type then +of+ option should be specified:
      #
      #   field :hobbies, :set, of: :string
      #
      # Only +string+, +integer+, +number+, +date+, +datetime+ and +serialized+
      # element types are supported.
      #
      # Element type can have own options - they should be specified in the
      # form of +Hash+:
      #
      #   field :hobbies, :set, of: { serialized: { serializer: JSON } }
      #
      # Array can contain element of different types but if supports the same
      # +of+ option to convert all the provided elements to the declared type.
      #
      #   field :rates, :array, of: :number
      #
      # By default +date+ and +datetime+ fields are stored as integer values.
      # The format can be changed to string with option +store_as_string+:
      #
      #   field :published_on, :datetime, store_as_string: true
      #
      # Boolean field by default is stored as a string +t+ or +f+. But DynamoDB
      # supports boolean type natively. In order to switch to the native
      # boolean type an option +store_as_native_boolean+ should be specified:
      #
      #   field :active, :boolean, store_as_native_boolean: true
      #
      # If you specify the +serialized+ type a value will be serialized to
      # string in Yaml format by default. Custom way to serialize value to
      # string can be specified with +serializer+ option. Custom serializer
      # should have +dump+ and +load+ methods.
      #
      # If you specify a class for field type, Dynamoid will serialize using
      # +dynamoid_dump+ method and load using +dynamoid_load+ method.
      #
      # Default field type is +string+.
      #
      # A field can have a default value. It's assigned at initializing a model
      # if no value is specified:
      #
      #   field :age, :integer, default: 1
      #
      # If a defautl value should be recalculated every time it can be
      # specified as a callable object (it should implement a +call+ method
      # e.g. +Proc+ object):
      #
      #   field :date_of_birth, :date, default: -> { Date.today }
      #
      # For every field Dynamoid creates several methods:
      #
      # * getter
      # * setter
      # * predicate +<name>?+ to check whether a value set
      # * +<name>_before_type_cast?+ to get an original field value before it was type casted
      #
      # It works in the following way:
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     field :age, :integer
      #   end
      #
      #   user = User.new
      #   user.age # => nil
      #   user.age? # => false
      #
      #   user.age = 20
      #   user.age? # => true
      #
      #   user.age = '21'
      #   user.age # => 21 - integer
      #   user.age_before_type_cast # => '21' - string
      #
      # There is also an option +alias+ which allows to use another name for a
      # field:
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     field :firstName, :string, alias: :first_name
      #   end
      #
      #   user = User.new(firstName: 'Michael')
      #   user.firstName # Michael
      #   user.first_name # Michael
      #
      # @param name [Symbol] name of the field
      # @param type [Symbol] type of the field (optional)
      # @param options [Hash] any additional options for the field type (optional)
      #
      # @since 0.2.0
      def field(name, type = :string, options = {})
        if type == :float
          Dynamoid.logger.warn("Field type :float, which you declared for '#{name}', is deprecated in favor of :number.")
          type = :number
        end

        Dynamoid::Fields::Declare.new(self, name, type, options).call
      end

      # Declare a table range key.
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     range :last_name
      #   end
      #
      # By default a range key is a string. In order to use any other type it
      # should be specified as a second argument:
      #
      #   range :age, :integer
      #
      # Type options can be specified as well:
      #
      #   range :date_of_birth, :date, store_as_string: true
      #
      # @param name [Symbol] a range key attribute name
      # @param type [Symbol] a range key type (optional)
      # @param options [Hash] type options (optional)
      def range(name, type = :string, options = {})
        field(name, type, options)
        self.range_key = name
      end

      # Set table level properties.
      #
      # There are some sensible defaults:
      #
      # * table name is based on a model class e.g. +users+ for +User+ class
      # * hash key name - +id+ by default
      # * hash key type - +string+ by default
      # * generating timestamp fields +created_at+ and +updated_at+
      # * billing mode and read/write capacity units
      #
      # The +table+ method can be used to override the defaults:
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     table name: :customers, key: :uuid
      #   end
      #
      # The hash key field is declared by default and a type is a string. If
      # another type is needed the field should be declared explicitly:
      #
      #   class User
      #     include Dynamoid::Document
      #
      #     field :id, :integer
      #   end
      #
      # @param options [Hash] options to override default table settings
      # @option options [Symbol] :name name of a table
      # @option options [Symbol] :key name of a hash key attribute
      # @option options [Symbol] :inheritance_field name of an attribute used for STI
      # @option options [Symbol] :capacity_mode table billing mode - either +provisioned+ or +on_demand+
      # @option options [Integer] :write_capacity table write capacity units
      # @option options [Integer] :read_capacity table read capacity units
      # @option options [true|false] :timestamps whether generate +created_at+ and +updated_at+ fields or not
      # @option options [Hash] :expires set up a table TTL and should have following structure +{ field: <attriubute name>, after: <seconds> }+
      #
      # @since 0.4.0
      def table(options)
        self.options = options

        # a default 'id' column is created when Dynamoid::Document is included
        unless attributes.key? hash_key
          remove_field :id
          field(hash_key)
        end

        # The created_at/updated_at fields are declared in the `included` callback first.
        # At that moment the only known setting is `Dynamoid::Config.timestamps`.
        # Now `options[:timestamps]` may override the global setting for a model.
        # So we need to make decision again and declare the fields or rollback thier declaration.
        #
        # Do not replace with `#timestamps_enabled?`.
        if options[:timestamps] && !Dynamoid::Config.timestamps
          # The fields weren't declared in `included` callback because they are disabled globaly
          field :created_at, :datetime
          field :updated_at, :datetime
        elsif options[:timestamps] == false && Dynamoid::Config.timestamps
          # The fields were declared in `included` callback but they are disabled for a table
          remove_field :created_at
          remove_field :updated_at
        end
      end

      # Remove a field declaration
      #
      # Removes a field from the list of fields and removes all te generated
      # for a field methods.
      #
      # @param field [Symbol] a field name
      def remove_field(field)
        field = field.to_sym
        attributes.delete(field) || raise('No such field')

        # Dirty API
        undefine_attribute_methods
        define_attribute_methods attributes.keys

        generated_methods.module_eval do
          remove_method field
          remove_method :"#{field}="
          remove_method :"#{field}?"
          remove_method :"#{field}_before_type_cast"
        end
      end

      # @private
      def timestamps_enabled?
        options[:timestamps] || (options[:timestamps].nil? && Dynamoid::Config.timestamps)
      end

      # @private
      def generated_methods
        @generated_methods ||= Module.new.tap do |mod|
          include(mod)
        end
      end
    end

    # You can access the attributes of an object directly on its attributes method, which is by default an empty hash.
    attr_accessor :attributes
    alias raw_attributes attributes

    # Write an attribute on the object.
    #
    #   user.age = 20
    #   user.write_attribute(:age, 21)
    #   user.age # => 21
    #
    # Also marks the previous value as dirty.
    #
    # @param name [Symbol] the name of the field
    # @param value [Object] the value to assign to that field
    # @return [Dynamoid::Document] self
    #
    # @since 0.2.0
    def write_attribute(name, value)
      name = name.to_sym
      old_value = read_attribute(name)

      unless attribute_is_present_on_model?(name)
        raise Dynamoid::Errors::UnknownAttribute, "Attribute #{name} is not part of the model"
      end

      if association = @associations[name]
        association.reset
      end

      @attributes_before_type_cast[name] = value

      value_casted = TypeCasting.cast_field(value, self.class.attributes[name])
      attribute_will_change!(name) if old_value != value_casted # Dirty API

      attributes[name] = value_casted
      self
    end
    alias []= write_attribute

    # Read an attribute from an object.
    #
    #   user.age = 20
    #   user.read_attribute(:age) # => 20
    #
    # @param name [Symbol] the name of the field
    # @return attribute value
    # @since 0.2.0
    def read_attribute(name)
      attributes[name.to_sym]
    end
    alias [] read_attribute

    # Return attributes values before type casting.
    #
    #   user = User.new
    #   user.age = '21'
    #   user.age # => 21
    #
    #   user.attributes_before_type_cast # => { age: '21' }
    #
    # @return [Hash] original attribute values
    def attributes_before_type_cast
      @attributes_before_type_cast
    end

    # Return the value of the attribute identified by name before type casting.
    #
    #   user = User.new
    #   user.age = '21'
    #   user.age # => 21
    #
    #   user.read_attribute_before_type_cast(:age) # => '21'
    #
    # @param name [Symbol] attribute name
    # @return original attribute value
    def read_attribute_before_type_cast(name)
      return nil unless name.respond_to?(:to_sym)

      @attributes_before_type_cast[name.to_sym]
    end

    private

    def set_expires_field
      options = self.class.options[:expires]

      if options.present?
        name = options[:field]
        seconds = options[:after]

        if self[name].blank?
          send(:"#{name}=", Time.now.to_i + seconds)
        end
      end
    end

    def set_inheritance_field
      # actually it does only following logic:
      # self.type ||= self.class.sti_name if self.class.attributes[:type]
      return if self.class.abstract_class?

      type = self.class.inheritance_field
      if self.class.attributes[type] && send(type).nil?
        send(:"#{type}=", self.class.sti_name)
      end
    end

    def attribute_is_present_on_model?(attribute_name)
      setter = :"#{attribute_name}="
      respond_to?(setter)
    end
  end
end
