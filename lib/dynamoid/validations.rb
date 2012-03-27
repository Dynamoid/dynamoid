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
    end
  end
end
