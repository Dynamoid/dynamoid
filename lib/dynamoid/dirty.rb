module Dynamoid
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::Dirty

    module ClassMethods
      def from_database(*)
        super.tap { |d| d.changed_attributes.clear }
      end
    end

    def save(*)
      clear_changes { super }
    end

    def reload
      super.tap { clear_changes }
    end

    def clear_changes
      previous = changes
      (block_given? ? yield : true).tap do |result|
        unless result == false #failed validation; nil is OK.
          @previously_changed = previous
          changed_attributes.clear
        end
      end
    end

    def write_attribute(name, value)
      attribute_will_change!(name) unless self.read_attribute(name) == value
      super
    end

    protected

    def attribute_method?(attr)
      super || self.class.attributes.has_key?(attr.to_sym)
    end
  end
end
