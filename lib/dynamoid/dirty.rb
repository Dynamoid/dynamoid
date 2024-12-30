# frozen_string_literal: true

module Dynamoid
  # Support interface of Rails' ActiveModel::Dirty module
  #
  # The reason why not just include ActiveModel::Dirty -
  # ActiveModel::Dirty conflicts either with @attributes or
  # #attributes in different Rails versions.
  #
  # Separate implementation (or copy-pasting) is the best way to
  # avoid endless monkey-patching
  #
  # Documentation:
  # https://api.rubyonrails.org/v4.2/classes/ActiveModel/Dirty.html
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      attribute_method_suffix '_changed?', '_change', '_will_change!', '_was'
      attribute_method_suffix '_previously_changed?', '_previous_change'
      attribute_method_affix prefix: 'restore_', suffix: '!'
    end

    # @private
    module ClassMethods
      def update_fields(*)
        super.tap do |model|
          model.clear_changes_information if model
        end
      end

      def upsert(*)
        super.tap do |model|
          model.clear_changes_information if model
        end
      end

      def from_database(attributes_from_database)
        super.tap do |model|
          model.clear_changes_information
          model.assign_attributes_from_database(DeepDupper.dup_attributes(model.attributes, model.class))
        end
      end
    end

    # @private
    def save(*)
      super.tap do |status|
        changes_applied if status
      end
    end

    # @private
    def save!(*)
      super.tap do
        changes_applied
      end
    end

    # @private
    def update(*)
      super.tap do
        clear_changes_information
      end
    end

    # @private
    def update!(*)
      super.tap do
        clear_changes_information
      end
    end

    # @private
    def reload(*)
      super.tap do
        clear_changes_information
      end
    end

    # Returns +true+ if any attribute have unsaved changes, +false+ otherwise.
    #
    #   person.changed? # => false
    #   person.name = 'Bob'
    #   person.changed? # => true
    #
    # @return [true|false]
    def changed?
      changed_attributes.present?
    end

    # Returns an array with names of the attributes with unsaved changes.
    #
    #   person = Person.new
    #   person.changed # => []
    #   person.name = 'Bob'
    #   person.changed # => ["name"]
    #
    # @return [Array[String]]
    def changed
      changed_attributes.keys
    end

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'Bob'
    #   person.changes # => { "name" => ["Bill", "Bob"] }
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    def changes
      ActiveSupport::HashWithIndifferentAccess[changed_attributes.map { |name, old_value| [name, [old_value, read_attribute(name)]] }]
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "Bob"
    #   person.name = 'Robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["Bob", "Robert"]}
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    def previous_changes
      @previously_changed ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Returns a hash of the attributes with unsaved changes indicating their original
    # values like <tt>attr => original value</tt>.
    #
    #   person.name # => "Bob"
    #   person.name = 'Robert'
    #   person.changed_attributes # => {"name" => "Bob"}
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    def changed_attributes
      attributes_changed_by_setter.merge(attributes_changed_in_place)
    end

    # Clear all dirty data: current changes and previous changes.
    def clear_changes_information
      @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
      @attributes_changed_by_setter = ActiveSupport::HashWithIndifferentAccess.new
      @attributes_from_database = HashWithIndifferentAccess.new(DeepDupper.dup_attributes(@attributes, self.class))
    end

    # Clears dirty data and moves +changes+ to +previous_changes+.
    def changes_applied
      @previously_changed = changes
      @attributes_changed_by_setter = ActiveSupport::HashWithIndifferentAccess.new
      @attributes_from_database = HashWithIndifferentAccess.new(DeepDupper.dup_attributes(@attributes, self.class))
    end

    # Remove changes information for the provided attributes.
    #
    # @param attributes [Array[String]] - a list of attributes to clear changes for
    def clear_attribute_changes(names)
      attributes_changed_by_setter.except!(*names)

      slice = HashWithIndifferentAccess.new(@attributes).slice(*names)
      attributes_from_database.merge!(DeepDupper.dup_attributes(slice, self.class))
    end

    # Handle <tt>*_changed?</tt> for +method_missing+.
    #
    #  person.attribute_changed?(:name) # => true
    #  person.attribute_changed?(:name, from: 'Alice')
    #  person.attribute_changed?(:name, to: 'Bob')
    #  person.attribute_changed?(:name, from: 'Alice', to: 'Bod')
    #
    # @private
    # @param name [Symbol] attribute name
    # @param options [Hash] conditions on +from+ and +to+ value (optional)
    # @option options [Symbol] :from previous attribute value
    # @option options [Symbol] :to current attribute value
    def attribute_changed?(name, options = {})
      result = changes_include?(name)
      result &&= options[:to] == read_attribute(name) if options.key?(:to)
      result &&= options[:from] == changed_attributes[name] if options.key?(:from)
      result
    end

    # Handle <tt>*_was</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.attribute_was(:name) # => "Alice"
    #
    # @private
    # @param name [Symbol] attribute name
    def attribute_was(name)
      attribute_changed?(name) ? changed_attributes[name] : read_attribute(name)
    end

    # Restore all previous data of the provided attributes.
    #
    # @param attributes [Array[Symbol]] a list of attribute names
    def restore_attributes(names = changed)
      names.each { |name| restore_attribute! name }
    end

    # Handles <tt>*_previously_changed?</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.save
    #  person.attribute_changed?(:name) # => true
    #
    # @private
    # @param name [Symbol] attribute name
    # @return [true|false]
    def attribute_previously_changed?(name)
      previous_changes_include?(name)
    end

    # Handles <tt>*_previous_change</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.save
    #  person.attribute_previously_changed(:name) # => ["Alice", "Bob"]
    #
    # @private
    # @param name [Symbol]
    # @return [Array]
    def attribute_previous_change(name)
      previous_changes[name] if attribute_previously_changed?(name)
    end

    # @private
    def assign_attributes_from_database(attributes_from_database)
      @attributes_from_database = HashWithIndifferentAccess.new(attributes_from_database)
    end

    private

    def changes_include?(name)
      attribute_changed_by_setter?(name) || attribute_changed_in_place?(name)
    end

    # Handle <tt>*_change</tt> for +method_missing+.
    def attribute_change(name)
      [changed_attributes[name], read_attribute(name)] if attribute_changed?(name)
    end

    # Handle <tt>*_will_change!</tt> for +method_missing+.
    def attribute_will_change!(name)
      return if attribute_changed?(name)

      begin
        value = read_attribute(name)
        value = value.clone if value.duplicable?
      rescue TypeError, NoMethodError
      end

      set_attribute_was(name, value)
    end

    # Handle <tt>restore_*!</tt> for +method_missing+.
    def restore_attribute!(name)
      if attribute_changed?(name)
        write_attribute(name, changed_attributes[name])
        clear_attribute_changes([name])
      end
    end

    # Returns +true+ if name were changed before the model was saved,
    # +false+ otherwise.
    def previous_changes_include?(name)
      previous_changes.include?(name)
    end

    def attributes_changed_by_setter
      @attributes_changed_by_setter ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    def attribute_changed_by_setter?(name)
      attributes_changed_by_setter.include?(name)
    end

    def attributes_from_database
      @attributes_from_database ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Force an attribute to have a particular "before" value
    def set_attribute_was(name, old_value)
      attributes_changed_by_setter[name] = old_value
    end

    def attributes_changed_in_place
      attributes_from_database.select do |name, _|
        attribute_changed_in_place?(name)
      end
    end

    def attribute_changed_in_place?(name)
      return false if attribute_changed_by_setter?(name)

      value_from_database = attributes_from_database[name]
      return false if value_from_database.nil?

      value = read_attribute(name)
      value != value_from_database
    end

    module DeepDupper
      def self.dup_attributes(attributes, klass)
        attributes.map do |name, value|
          type_options = klass.attributes[name.to_sym]
          value_duplicate = dup_attribute(value, type_options)
          [name, value_duplicate]
        end.to_h
      end

      def self.dup_attribute(value, type_options)
        type, of = type_options.values_at(:type, :of)

        case value
        when NilClass, TrueClass, FalseClass, Numeric, Symbol, IO
          # till Ruby 2.4 these immutable objects could not be duplicated
          # IO objects cannot be duplicated - is used for binary fields
          value
        when String
          value.dup
        when Array
          if of.is_a? Class # custom type
            value.map { |e| dup_attribute(e, type: of) }
          else
            value.deep_dup
          end
        when Set
          Set.new(value.map { |e| dup_attribute(e, type: of) })
        when Hash
          value.deep_dup
        else
          if type.is_a? Class # custom type
            Marshal.load(Marshal.dump(value)) # dup instance variables
          else
            value.dup # date, datetime
          end
        end
      end
    end
  end
end
