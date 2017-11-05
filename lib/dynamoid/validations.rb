# encoding: utf-8
module Dynamoid

  # Provide ActiveModel validations to Dynamoid documents.
  module Validations
    extend ActiveSupport::Concern

    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks

    # Override save to provide validation support.
    #
    # @since 0.2.0
    def save(options = {})
      options.reverse_merge!(:validate => true)
      return false if options[:validate] and (not valid?)
      super
    end

    # Is this object valid?
    #
    # @since 0.2.0
    def valid?(context = nil)
      context ||= (new_record? ? :create : :update)
      super(context)
    end

    # Raise an error unless this object is valid.
    #
    # @since 0.2.0
    def save!
      raise Dynamoid::Errors::DocumentNotValid.new(self) unless valid?
      save(:validate => false)
      self
    end

    module ClassMethods

      # Override validates_presence_of to handle false values as present.
      #
      # @since 1.1.1
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end

      private

      # Validates that the specified attributes are present (false or not blank).
      class PresenceValidator < ActiveModel::EachValidator
        # Validate the record for the record and value.
        def validate_each(record, attr_name, value)
          record.errors.add(attr_name, :blank, options) if not_present?(value)
        end

        private

        # Check whether a value is not present.
        def not_present?(value)
          value.blank? && value != false
        end
      end
    end
  end
end
