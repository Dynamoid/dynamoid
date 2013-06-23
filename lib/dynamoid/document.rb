# encoding: utf-8
module Dynamoid #:nodoc:

  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components

    included do
      class_attribute :options, :read_only_attributes, :base_class
      self.options = {}
      self.read_only_attributes = []
      self.base_class = self

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
        super if defined? super
      end

      def attr_readonly(*read_only_attributes)
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
        Dynamoid::Adapter::AwsSdk.count(table_name)
      end

      # Initialize a new object and immediately save it to the database.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create(attrs = {})
        attrs[:type] ? attrs[:type].constantize.new(attrs).tap(&:save) : new(attrs).tap(&:save)
      end

      # Initialize a new object and immediately save it to the database. Raise an exception if persistence failed.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create!(attrs = {})
        attrs[:type] ? attrs[:type].constantize.new(attrs).tap(&:save!) : new(attrs).tap(&:save!)
      end

      # Initialize a new object.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the new document
      #
      # @since 0.2.0
      def build(attrs = {})
        attrs[:type] ? attrs[:type].constantize.new(attrs) : new(attrs)
      end

      # Does this object exist?
      #
      # @param [Mixed] id_or_conditions the id of the object or a hash with the options to filter from.
      #
      # @return [Boolean] true/false
      #
      # @since 0.2.0
      def exists?(id_or_conditions = {})
        case id_or_conditions
          when Hash then ! where(id_or_conditions).all.empty?
          else !! find(id_or_conditions)
        end
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

        load(attrs)
      end
    end

    def load(attrs)
      self.class.undump(attrs).each {|key, value| send "#{key}=", value }
    end

    # An object is equal to another object if their ids are equal.
    #
    # @since 0.2.0
    def ==(other)
      if self.class.identity_map_on?
        super
      else
        return false if other.nil?
        other.is_a?(Dynamoid::Document) && self.hash_key == other.hash_key && self.range_value == other.range_value
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      hash_key.hash ^ range_value.hash
    end

    # Reload an object from the database -- if you suspect the object has changed in the datastore and you need those
    # changes to be reflected immediately, you would call this method. This is a consistent read.
    #
    # @return [Dynamoid::Document] the document this method was called on
    #
    # @since 0.2.0
    def reload
      range_key_value = range_value ? dumped_range_value : nil
      self.attributes = self.class.find(hash_key, :range_key => range_key_value, :consistent_read => true).attributes
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
    def hash_key=(value)
      self.send("#{self.class.hash_key}=", value)
    end

    def range_value
      if range_key = self.class.range_key
        self.send(range_key)
      end
    end

    def range_value=(value)
      self.send("#{self.class.range_key}=", value)
    end

    private

    def dumped_range_value
      dump_field(range_value, self.class.attributes[self.class.range_key])
    end
  end
end
