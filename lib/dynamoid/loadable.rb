# frozen_string_literal: true

module Dynamoid
  module Loadable
    extend ActiveSupport::Concern

    def load(attrs)
      attrs.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

    # Reload an object from the database -- if you suspect the object has changed in the data store and you need those
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

      self.attributes = self.class.find(hash_key, **options).attributes

      @associations.values.each(&:reset)
      @new_record = false

      self
    end
  end
end
