# frozen_string_literal: true

module Dynamoid
  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components

    included do
      class_attribute :options, :read_only_attributes, :base_class, :dynamoid_config_name, instance_accessor: false
      self.options = {}
      self.read_only_attributes = []
      self.base_class = self
      self.dynamoid_config_name = nil

      Dynamoid.included_models << self unless Dynamoid.included_models.include? self
    end

    module ClassMethods
      def attr_readonly(*read_only_attributes)
        self.read_only_attributes.concat read_only_attributes.map(&:to_s)
      end

      # Set the DynamoDB configuration to use for this model
      #
      # @param [Symbol] config_name the name of the configuration
      # @since 4.0.0
      def dynamoid_config(config_name)
        self.dynamoid_config_name = config_name.to_sym
      end

      # Get the adapter for this model's configuration
      #
      # @return [Dynamoid::Adapter] the adapter instance
      # @since 4.0.0
      def adapter
        if dynamoid_config_name
          Dynamoid::MultiConfig.get_adapter(dynamoid_config_name)
        else
          Dynamoid.adapter
        end
      end

      # Returns the read capacity for this table.
      #
      # @return [Integer] read capacity units
      # @since 0.4.0
      def read_capacity
        options[:read_capacity] || Dynamoid::Config.read_capacity
      end

      # Returns the write_capacity for this table.
      #
      # @return [Integer] write capacity units
      # @since 0.4.0
      def write_capacity
        options[:write_capacity] || Dynamoid::Config.write_capacity
      end

      # Returns the billing (capacity) mode for this table.
      #
      # Could be either +provisioned+ or +on_demand+.
      #
      # @return [Symbol]
      def capacity_mode
        options[:capacity_mode] || Dynamoid::Config.capacity_mode
      end

      # Returns the field name used to support STI for this table.
      #
      # Default field name is +type+ but it can be overrided in the +table+
      # method call.
      #
      #   User.inheritance_field # => :type
      def inheritance_field
        options[:inheritance_field] || :type
      end

      # Returns the hash key field name for this class.
      #
      # By default +id+ field is used. But it can be overriden in the +table+
      # method call.
      #
      #   User.hash_key # => :id
      #
      # @return [Symbol] a hash key name
      # @since 0.4.0
      def hash_key
        options[:key] || :id
      end

      # Return the count of items for this class.
      #
      # It returns approximate value based on DynamoDB statistic. DynamoDB
      # updates it periodically so the value can be no accurate.
      #
      # It's a reletively cheap operation and doesn't read all the items in a
      # table. It makes just one HTTP request to DynamoDB.
      #
      # @return [Integer] items count in a table
      # @since 0.6.1
      def count
        adapter.count(table_name)
      end

      # Initialize a new object.
      #
      #   User.build(name: 'A')
      #
      # Initialize an object and pass it into a block to set other attributes.
      #
      #   User.build(name: 'A') do |u|
      #     u.age = 21
      #   end
      #
      # The only difference between +build+ and +new+ methods is that +build+
      # supports STI (Single table inheritance) and looks at the inheritance
      # field. So it can build a model of actual class. For instance:
      #
      #   class Employee
      #     include Dynamoid::Document
      #
      #     field :type
      #     field :name
      #   end
      #
      #   class Manager < Employee
      #   end
      #
      #   Employee.build(name: 'Alice', type: 'Manager') # => #<Manager:0x00007f945756e3f0 ...>
      #
      # @param attrs [Hash] Attributes with which to create the document
      # @param block [Proc] Block to process a document after initialization
      # @return [Dynamoid::Document] the new document
      # @since 0.2.0
      def build(attrs = {}, &block)
        choose_right_class(attrs).new(attrs, &block)
      end

      # Does this model exist in a table?
      #
      #   User.exists?('713') # => true
      #
      # If a range key is declared it should be specified in the following way:
      #
      #   User.exists?([['713', 'range-key-value']]) # => true
      #
      # It's possible to check existence of several models at once:
      #
      #   User.exists?(['713', '714', '715'])
      #
      # Or in case when a range key is declared:
      #
      #   User.exists?(
      #     [
      #       ['713', 'range-key-value-1'],
      #       ['714', 'range-key-value-2'],
      #       ['715', 'range-key-value-3']
      #     ]
      #   )
      #
      # It's also possible to specify models not with primary key but with
      # conditions on the attributes (in the +where+ method style):
      #
      #   User.exists?(age: 20, 'created_at.gt': Time.now - 1.day)
      #
      # @param id_or_conditions [String|Array[String]|Array[Array]|Hash] the primary id of the model, a list of primary ids or a hash with the options to filter from.
      # @return [true|false]
      # @since 0.2.0
      def exists?(id_or_conditions = {})
        case id_or_conditions
        when Hash then where(id_or_conditions).count >= 1
        else
          begin
            find(id_or_conditions)
            true
          rescue Dynamoid::Errors::RecordNotFound
            false
          end
        end
      end

      attr_accessor :abstract_class

      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def sti_name
        name
      end

      def sti_class_for(type_name)
        type_name.constantize
      rescue NameError
        raise Errors::SubclassNotFound, "STI subclass does not found. Subclass: '#{type_name}'"
      end

      # @private
      def deep_subclasses
        subclasses + subclasses.map(&:deep_subclasses).flatten
      end

      # @private
      def choose_right_class(attrs)
        attrs[inheritance_field] ? sti_class_for(attrs[inheritance_field]) : self
      end
    end

    # Initialize a new object.
    #
    #   User.new(name: 'A')
    #
    # Initialize an object and pass it into a block to set other attributes.
    #
    #   User.new(name: 'A') do |u|
    #     u.age = 21
    #   end
    #
    # @param attrs [Hash] Attributes with which to create the document
    # @param block [Proc] Block to process a document after initialization
    # @return [Dynamoid::Document] the new document
    #
    # @since 0.2.0
    def initialize(attrs = {}, &block)
      run_callbacks :initialize do
        @new_record = true
        @attributes ||= {}
        @associations ||= {}
        @attributes_before_type_cast ||= {}

        attrs_with_defaults = self.class.attributes.each_with_object({}) do |(attribute, options), res|
          if attrs.key?(attribute)
            res[attribute] = attrs[attribute]
          elsif options.key?(:default)
            res[attribute] = evaluate_default_value(options[:default])
          end
        end

        attrs_virtual = attrs.slice(*(attrs.keys - self.class.attributes.keys))

        load(attrs_with_defaults.merge(attrs_virtual))

        if block
          yield(self)
        end
      end
    end

    # Check equality of two models.
    #
    # A model is equal to another model only if their primary keys (hash key
    # and optionally range key) are equal.
    #
    # @return [true|false]
    # @since 0.2.0
    def ==(other)
      if self.class.identity_map_on?
        super
      else
        return false if other.nil?

        other.is_a?(Dynamoid::Document) && hash_key == other.hash_key && range_value == other.range_value
      end
    end

    # Check equality of two models.
    #
    # Works exactly like +==+ does.
    #
    # @return [true|false]
    def eql?(other)
      self == other
    end

    # Generate an Integer hash value for this model.
    #
    # Hash value is based on primary key. So models can be used safely as a
    # +Hash+ keys.
    #
    # @return [Integer]
    def hash
      [hash_key, range_value].hash
    end

    # Return a model's hash key value.
    #
    # @since 0.4.0
    def hash_key
      self[self.class.hash_key.to_sym]
    end

    # Assign a model's hash key value, regardless of what it might be called to
    # the object.
    #
    # @since 0.4.0
    def hash_key=(value)
      self[self.class.hash_key.to_sym] = value
    end

    # Return a model's range key value.
    #
    # Returns +nil+ if a range key isn't declared for a model.
    def range_value
      if self.class.range_key
        self[self.class.range_key.to_sym]
      end
    end

    # Assign a model's range key value.
    def range_value=(value)
      if self.class.range_key
        self[self.class.range_key.to_sym] = value
      end
    end

    def inspect
      # attributes order is:
      # - partition key
      # - sort key
      # - user defined attributes
      # - timestamps - created_at/updated_at
      names = [self.class.hash_key]
      names << self.class.range_key if self.class.range_key
      names += self.class.attributes.keys - names - %i[created_at updated_at]
      names << :created_at if self.class.attributes.key?(:created_at)
      names << :updated_at if self.class.attributes.key?(:updated_at)

      inspection = names.map do |name|
        value = read_attribute(name)
        "#{name}: #{value.inspect}"
      end.join(', ')

      "#<#{self.class.name} #{inspection}>"
    end

    private

    def dumped_range_value
      Dumping.dump_field(range_value, self.class.attributes[self.class.range_key])
    end

    # Evaluates the default value given, this is used by undump
    # when determining the value of the default given for a field options.
    #
    # @param val [Object] the attribute's default value
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
end

ActiveSupport.run_load_hooks(:dynamoid, Dynamoid::Document)
