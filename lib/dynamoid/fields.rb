# encoding: utf-8
module Dynamoid #:nodoc:

  module Fields
    extend ActiveSupport::Concern

    included do
      class_attribute :fields
      
      self.fields = []
      field :id
    end
    
    module ClassMethods
      def field(name, options = {})
        named = name.to_s
        self.fields << name
        define_method(named) do
          read_attribute(named)
        end
        define_method("#{named}=") do |value|
          write_attribute(named, value)
        end
        define_method("#{named}?") do
          !read_attribute(named).nil?
        end
      end
    end
    
  end
  
end