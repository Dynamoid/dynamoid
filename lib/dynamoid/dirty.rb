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

    module ClassMethods
      def update_fields(*)
        if model = super
          model.send(:clear_changes_information)
        end
        model
      end

      def upsert(*)
        if model = super
          model.send(:clear_changes_information)
        end
        model
      end

      def from_database(*)
        super.tap do |m|
          m.send(:clear_changes_information)
        end
      end
    end

    def save(*)
      if status = super
        changes_applied
      end
      status
    end

    def save!(*)
      super.tap do
        changes_applied
      end
    end

    def update(*)
      super.tap do
        clear_changes_information
      end
    end

    def update!(*)
      super.tap do
        clear_changes_information
      end
    end

    def reload(*)
      super.tap do
        clear_changes_information
      end
    end

    # Returns +true+ if any attribute have unsaved changes, +false+ otherwise.
    #
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      changed_attributes.present?
    end

    # Returns an array with the name of the attributes with unsaved changes.
    #
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ["name"]
    def changed
      changed_attributes.keys
    end

    # Returns a hash of changed attributes indicating their original
    # and new values like <tt>attr => [original value, new value]</tt>.
    #
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { "name" => ["bill", "bob"] }
    def changes
      ActiveSupport::HashWithIndifferentAccess[changed.map { |attr| [attr, attribute_change(attr)] }]
    end

    # Returns a hash of attributes that were changed before the model was saved.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.save
    #   person.previous_changes # => {"name" => ["bob", "robert"]}
    def previous_changes
      @previously_changed ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Returns a hash of the attributes with unsaved changes indicating their original
    # values like <tt>attr => original value</tt>.
    #
    #   person.name # => "bob"
    #   person.name = 'robert'
    #   person.changed_attributes # => {"name" => "bob"}
    def changed_attributes
      @changed_attributes ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    # Handle <tt>*_changed?</tt> for +method_missing+.
    def attribute_changed?(attr, options = {}) #:nodoc:
      result = changes_include?(attr)
      result &&= options[:to] == __send__(attr) if options.key?(:to)
      result &&= options[:from] == changed_attributes[attr] if options.key?(:from)
      result
    end

    # Handle <tt>*_was</tt> for +method_missing+.
    def attribute_was(attr) # :nodoc:
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end

    # Restore all previous data of the provided attributes.
    def restore_attributes(attributes = changed)
      attributes.each { |attr| restore_attribute! attr }
    end

    # Handles <tt>*_previously_changed?</tt> for +method_missing+.
    def attribute_previously_changed?(attr) #:nodoc:
      previous_changes_include?(attr)
    end

    # Handles <tt>*_previous_change</tt> for +method_missing+.
    def attribute_previous_change(attr)
      previous_changes[attr] if attribute_previously_changed?(attr)
    end

    private

    def changes_include?(attr_name)
      attributes_changed_by_setter.include?(attr_name)
    end
    alias attribute_changed_by_setter? changes_include?

    # Removes current changes and makes them accessible through +previous_changes+.
    def changes_applied # :doc:
      @previously_changed = changes
      @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
    end

    # Clear all dirty data: current changes and previous changes.
    def clear_changes_information # :doc:
      @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
      @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
    end

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
    alias attributes_changed_by_setter changed_attributes # :nodoc:

    # Force an attribute to have a particular "before" value
    def set_attribute_was(attr, old_value)
      attributes_changed_by_setter[attr] = old_value
    end

    # Remove changes information for the provided attributes.
    def clear_attribute_changes(attributes) # :doc:
      attributes_changed_by_setter.except!(*attributes)
    end
  end
end
