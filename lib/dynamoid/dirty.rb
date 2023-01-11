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
          model.send(:clear_changes_information) if model
        end
      end

      def upsert(*)
        super.tap do |model|
          model.send(:clear_changes_information) if model
        end
      end

      def from_database(*)
        super.tap do |m|
          m.send(:clear_changes_information)
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
      ActiveSupport::HashWithIndifferentAccess[changed.map { |attr| [attr, attribute_change(attr)] }]
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
      @changed_attributes ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Clear all dirty data: current changes and previous changes.
    def clear_changes_information # :doc:
      @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
      @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
    end

    # Removes current changes and makes them accessible through +previous_changes+.
    def changes_applied # :doc:
      @previously_changed = changes
      @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
    end

    # Remove changes information for the provided attributes.
    #
    # @param attributes [Array[String]] - a list of attributes to clear changes for
    def clear_attribute_changes(attributes)
      attributes_changed_by_setter.except!(*attributes)
    end

    # Handle <tt>*_changed?</tt> for +method_missing+.
    #
    #  person.attribute_changed?(:name) # => true
    #  person.attribute_changed?(:name, from: 'Alice')
    #  person.attribute_changed?(:name, to: 'Bob')
    #  person.attribute_changed?(:name, from: 'Alice', to: 'Bod')
    #
    # @private
    # @param attr [Symbol] attribute name
    # @param options [Hash] conditions on +from+ and +to+ value (optional)
    # @option options [Symbol] :from previous attribute value
    # @option options [Symbol] :to current attribute value
    def attribute_changed?(attr, options = {})
      result = changes_include?(attr)
      result &&= options[:to] == __send__(attr) if options.key?(:to)
      result &&= options[:from] == changed_attributes[attr] if options.key?(:from)
      result
    end

    # Handle <tt>*_was</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.attribute_was(:name) # => "Alice"
    #
    # @private
    # @param attr [Symbol] attribute name
    def attribute_was(attr)
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end

    # Restore all previous data of the provided attributes.
    #
    # @param attributes [Array[Symbol]] a list of attribute names
    def restore_attributes(attributes = changed)
      attributes.each { |attr| restore_attribute! attr }
    end

    # Handles <tt>*_previously_changed?</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.save
    #  person.attribute_changed?(:name) # => true
    #
    # @private
    # @param attr [Symbol] attribute name
    # @return [true|false]
    def attribute_previously_changed?(attr)
      previous_changes_include?(attr)
    end

    # Handles <tt>*_previous_change</tt> for +method_missing+.
    #
    #  person = Person.create(name: 'Alice')
    #  person.name = 'Bob'
    #  person.save
    #  person.attribute_previously_changed(:name) # => ["Alice", "Bob"]
    #
    # @private
    # @param attr [Symbol]
    # @return [Array]
    def attribute_previous_change(attr)
      previous_changes[attr] if attribute_previously_changed?(attr)
    end

    private

    def changes_include?(attr_name)
      attributes_changed_by_setter.include?(attr_name)
    end
    alias attribute_changed_by_setter? changes_include?

    # Handle <tt>*_change</tt> for +method_missing+.
    def attribute_change(attr)
      [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
    end

    # Handle <tt>*_will_change!</tt> for +method_missing+.
    def attribute_will_change!(attr)
      return if attribute_changed?(attr)

      begin
        value = __send__(attr)
        value = value.duplicable? ? value.clone : value
      rescue TypeError, NoMethodError
      end

      set_attribute_was(attr, value)
    end

    # Handle <tt>restore_*!</tt> for +method_missing+.
    def restore_attribute!(attr)
      if attribute_changed?(attr)
        __send__("#{attr}=", changed_attributes[attr])
        clear_attribute_changes([attr])
      end
    end

    # Returns +true+ if attr_name were changed before the model was saved,
    # +false+ otherwise.
    def previous_changes_include?(attr_name)
      previous_changes.include?(attr_name)
    end

    # This is necessary because `changed_attributes` might be overridden in
    # other implemntations (e.g. in `ActiveRecord`)
    alias attributes_changed_by_setter changed_attributes

    # Force an attribute to have a particular "before" value
    def set_attribute_was(attr, old_value)
      attributes_changed_by_setter[attr] = old_value
    end
  end
end
