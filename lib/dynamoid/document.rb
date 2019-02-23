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

      # Initialize a new object and immediately save it to the database.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create(attrs = {})
        if attrs.is_a?(Array)
          attrs.map { |attr| create(attr) }
        else
          build(attrs).tap(&:save)
        end
      end

      # Initialize a new object and immediately save it to the database. Raise an exception if persistence failed.
      #
      # @param [Hash] attrs Attributes with which to create the object.
      #
      # @return [Dynamoid::Document] the saved document
      #
      # @since 0.2.0
      def create!(attrs = {})
        if attrs.is_a?(Array)
          attrs.map { |attr| create!(attr) }
        else
          build(attrs).tap(&:save!)
        end
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

      # Update document with provided values.
      # Instantiates document and saves changes. Runs validations and callbacks.
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key, optional
      # @param [Hash] attributes
      #
      # @return [Dynamoid::Doument] updated document
      #
      # @example Update document
      #   Post.update(101, read: true)
      def update(hash_key, range_key_value = nil, attrs)
        model = find(hash_key, range_key: range_key_value, consistent_read: true)
        model.update_attributes(attrs)
        model
      end

      # Update document.
      # Uses efficient low-level `UpdateItem` API call.
      # Changes attibutes and loads new document version with one API call.
      # Doesn't run validations and callbacks. Can make conditional update.
      # If a document doesn't exist or specified conditions failed - returns `nil`
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key (optional)
      # @param [Hash] attributes
      # @param [Hash] conditions
      #
      # @return [Dynamoid::Document/nil] updated document
      #
      # @example Update document
      #   Post.update_fields(101, read: true)
      #
      # @example Update document with condition
      #   Post.update_fields(101, { read: true }, if: { version: 1 })
      def update_fields(hash_key_value, range_key_value = nil, attrs = {}, conditions = {})
        optional_params = [range_key_value, attrs, conditions].compact
        if optional_params.first.is_a?(Hash)
          range_key_value = nil
          attrs, conditions = optional_params[0..1]
        else
          range_key_value = optional_params.first
          attrs, conditions = optional_params[1..2]
        end

        options = if range_key
                    value_casted = TypeCasting.cast_field(range_key_value, attributes[range_key])
                    value_dumped = Dumping.dump_field(value_casted, attributes[range_key])
                    { range_key: value_dumped }
                  else
                    {}
                  end

        (conditions[:if_exists] ||= {})[hash_key] = hash_key_value
        options[:conditions] = conditions

        attrs = attrs.symbolize_keys
        if Dynamoid::Config.timestamps
          attrs[:updated_at] ||= DateTime.now.in_time_zone(Time.zone)
        end

        begin
          new_attrs = Dynamoid.adapter.update_item(table_name, hash_key_value, options) do |t|
            attrs.each do |k, v|
              value_casted = TypeCasting.cast_field(v, attributes[k])
              value_dumped = Dumping.dump_field(value_casted, attributes[k])
              t.set(k => value_dumped)
            end
          end
          attrs_undumped = Undumping.undump_attributes(new_attrs, attributes)
          new(attrs_undumped)
        rescue Dynamoid::Errors::ConditionalCheckFailedException
        end
      end


      # Update existing document or create new one.
      # Similar to `.update_fields`. The only diffirence is creating new document.
      #
      # Uses efficient low-level `UpdateItem` API call.
      # Changes attibutes and loads new document version with one API call.
      # Doesn't run validations and callbacks. Can make conditional update.
      # If specified conditions failed - returns `nil`
      #
      # @param [Scalar value] partition key
      # @param [Scalar value] sort key (optional)
      # @param [Hash] attributes
      # @param [Hash] conditions
      #
      # @return [Dynamoid::Document/nil] updated document
      #
      # @example Update document
      #   Post.update(101, read: true)
      #
      # @example Update document
      #   Post.upsert(101, read: true)
      def upsert(hash_key_value, range_key_value = nil, attrs = {}, conditions = {})
        optional_params = [range_key_value, attrs, conditions].compact
        if optional_params.first.is_a?(Hash)
          range_key_value = nil
          attrs, conditions = optional_params[0..1]
        else
          range_key_value = optional_params.first
          attrs, conditions = optional_params[1..2]
        end

        options = if range_key
                    value_casted = TypeCasting.cast_field(range_key_value, attributes[range_key])
                    value_dumped = Dumping.dump_field(value_casted, attributes[range_key])
                    { range_key: value_dumped }
                  else
                    {}
                  end

        options[:conditions] = conditions

        attrs = attrs.symbolize_keys
        if Dynamoid::Config.timestamps
          attrs[:updated_at] ||= DateTime.now.in_time_zone(Time.zone)
        end

        begin
          new_attrs = Dynamoid.adapter.update_item(table_name, hash_key_value, options) do |t|
            attrs.each do |k, v|
              value_casted = TypeCasting.cast_field(v, attributes[k])
              value_dumped = Dumping.dump_field(value_casted, attributes[k])

              t.set(k => value_dumped)
            end
          end

          attrs_undumped = Undumping.undump_attributes(new_attrs, attributes)
          new(attrs_undumped)
        rescue Dynamoid::Errors::ConditionalCheckFailedException
        end
      end

      def inc(hash_key_value, range_key_value=nil, counters)
        options = if range_key
                    value_casted = TypeCasting.cast_field(range_key_value, attributes[range_key])
                    value_dumped = Dumping.dump_field(value_casted, attributes[range_key])
                    { range_key: value_dumped }
                  else
                    {}
                  end

        Dynamoid.adapter.update_item(table_name, hash_key_value, options) do |t|
          counters.each do |k, v|
            value_casted = TypeCasting.cast_field(v, attributes[k])
            value_dumped = Dumping.dump_field(value_casted, attributes[k])

            t.add(k => value_dumped)
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

        self.class.attributes.each do |_, options|
          if options[:type].is_a?(Class) && options[:default]
            raise 'Dynamoid class-type fields do not support default values'
          end
        end

        attrs_with_defaults = {}
        self.class.attributes.each do |attribute, options|
          attrs_with_defaults[attribute] = if attrs.key?(attribute)
                                             attrs[attribute]
                                           elsif options.key?(:default)
                                             evaluate_default_value(options[:default])
                                           end
        end

        attrs_virtual = attrs.slice(*(attrs.keys - self.class.attributes.keys))

        load(attrs_with_defaults.merge(attrs_virtual))
      end
    end

    def load(attrs)
      attrs.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
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

    # Reload an object from the database -- if you suspect the object has changed in the datastore and you need those
    # changes to be reflected immediately, you would call this method. This is a consistent read.
    #
    # @return [Dynamoid::Document] the document this method was called on
    #
    # @since 0.2.0
    def reload
      options = { consistent_read: true }

      if self.class.range_key
        options[:range_key] = range_value
      end

      self.attributes = self.class.find(hash_key, options).attributes
      @associations.values.each(&:reset)
      self
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
