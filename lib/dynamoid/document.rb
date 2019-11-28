# frozen_string_literal: true

module Dynamoid #:nodoc:
  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components

    included do
      class_attribute :options, :read_only_attributes, :base_class, instance_accessor: false
      self.options = {}
      self.read_only_attributes = []
      self.base_class = self

      Dynamoid.included_models << self unless Dynamoid.included_models.include? self
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
        super if defined? super
      end

      def attr_readonly(*read_only_attributes)
        ActiveSupport::Deprecation.warn('[Dynamoid] .attr_readonly is deprecated! Call .find instead of')
        self.read_only_attributes.concat read_only_attributes.map(&:to_s)
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


      # Returns the billing (capacity) mode for this table.
      # Could be either :provisioned or :on_demand
      def capacity_mode
        options[:capacity_mode] || Dynamoid::Config.capacity_mode
      end

      # Returns the field name used to support STI for this table.
      def inheritance_field
        options[:inheritance_field] || :type
      end

      # Returns the id field for this class.
      #
      # @since 0.4.0
      def hash_key
        options[:key] || :id
      end

      # Returns the number of items for this class.
      #
      # @since 0.6.1
      def count
        Dynamoid.adapter.count(table_name)
      end

      # Initialize a new object.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the new document
      #
      # @since 0.2.0
      def build(attrs = {})
        choose_right_class(attrs).new(attrs)
      end

      # Does this object exist?
      #
      # Supports primary key in format that `find` call understands.
      # Multiple keys and single compound primary key should be passed only as Array explicitily.
      #
      # Supports conditions in format that `where` call understands.
      #
      # @param [Mixed] id_or_conditions the id of the object or a hash with the options to filter from.
      #
      # @return [Boolean] true/false
      #
      # @example With id
      #
      #   Post.exist?(713)
      #   Post.exist?([713, 210])
      #
      # @example With attributes conditions
      #
      #   Post.exist?(version: 1, 'created_at.gt': Time.now - 1.day)
      #
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

      def deep_subclasses
        subclasses + subclasses.map(&:deep_subclasses).flatten
      end

      def choose_right_class(attrs)
        attrs[inheritance_field] ? attrs[inheritance_field].constantize : self
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
      end
    end

    # An object is equal to another object if their ids are equal.
    #
    # @since 0.2.0
    def ==(other)
      if self.class.identity_map_on?
        super
      else
        return false if other.nil?

        other.is_a?(Dynamoid::Document) && hash_key == other.hash_key && range_value == other.range_value
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      hash_key.hash ^ range_value.hash
    end

    # Return an object's hash key, regardless of what it might be called to the object.
    #
    # @since 0.4.0
    def hash_key
      send(self.class.hash_key)
    end

    # Assign an object's hash key, regardless of what it might be called to the object.
    #
    # @since 0.4.0
    def hash_key=(value)
      send("#{self.class.hash_key}=", value)
    end

    def range_value
      if range_key = self.class.range_key
        send(range_key)
      end
    end

    def range_value=(value)
      send("#{self.class.range_key}=", value)
    end

    private

    def dumped_range_value
      Dumping.dump_field(range_value, self.class.attributes[self.class.range_key])
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
end
