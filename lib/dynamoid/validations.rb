# encoding: utf-8
module Dynamoid #:nodoc:
  module Validations
    extend ActiveSupport::Concern

    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks

    def save(options = {})
      options.reverse_merge!(:validate => true)
      return false if options[:validate] and (not valid?)
      super()
    end

    def valid?(context = nil)
      context ||= (new_record? ? :create : :update)
      super(context)
    end

    def save!
      raise Dynamoid::Errors::DocumentNotValid.new(self) unless valid?
      save(:validate => false)
    end
  end
end
