# frozen_string_literal: true

module Dynamoid
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::Dirty

    module ClassMethods
      def from_database(*)
        super.tap { |d| d.send(:clear_changes_information) }
      end
    end

    def save(*)
      clear_changes { super }
    end

    def update!(*)
      ret = super
      clear_changes # update! completely reloads all fields on the class, so any extant changes are wiped out
      ret
    end

    def reload
      super.tap { clear_changes }
    end

    def clear_changes
      previous = changes
      (block_given? ? yield : true).tap do |result|
        unless result == false # failed validation; nil is OK.
          @previously_changed = previous
          clear_changes_information
        end
      end
    end

    def write_attribute(name, value)
      attribute_will_change!(name) unless read_attribute(name) == value
      super
    end

    protected

    def attribute_method?(attr)
      super || self.class.attributes.key?(attr.to_sym)
    end

    if ActiveModel::VERSION::STRING >= '5.2.0'
      # The ActiveModel::Dirty API was changed
      # https://github.com/rails/rails/commit/c3675f50d2e59b7fc173d7b332860c4b1a24a726#diff-aaddd42c7feb0834b1b5c66af69814d3
      # So we just try to disable new functionality

      def mutations_from_database
        @mutations_from_database ||= ActiveModel::NullMutationTracker.instance
      end

      def forget_attribute_assignments; end
    end

    if ActiveModel::VERSION::STRING < '4.2.0'
      def clear_changes_information
        changed_attributes.clear
      end
    end
  end
end
