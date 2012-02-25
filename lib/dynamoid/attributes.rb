# encoding: utf-8
module Dynamoid #:nodoc:

  module Attributes
    extend ActiveSupport::Concern
    
    attr_accessor :attributes
    alias :raw_attributes :attributes
      
    def write_attribute(name, value)
      attributes[name.to_sym] = value
    end
    alias :[]= :write_attribute
    
    def read_attribute(name)
      attributes[name.to_sym]
    end
    alias :[] :read_attribute
    
    def update_attributes(attributes)
      self.attributes = attributes
      save
    end
    
    def update_attribute(attribute, value)
      self.attributes[attribute] = value
      save
    end
    
    module ClassMethods
      def attributes
        [self.fields + [:id]].flatten.uniq
      end
    end
  end
  
end