require 'dynamoid/associations/association'
require 'dynamoid/associations/has_many'
require 'dynamoid/associations/belongs_to'
require 'dynamoid/associations/has_one'
require 'dynamoid/associations/has_and_belongs_to_many'

# encoding: utf-8
module Dynamoid #:nodoc:

  # Connects models together through the magic of associations.
  module Associations
    extend ActiveSupport::Concern
    
    included do
      class_attribute :associations
      
      self.associations = {}
    end

    module ClassMethods
      def has_many(name, options = {})
        association(:has_many, name, options)
      end
      
      def has_one(name, options = {})
        association(:has_one, name, options)
      end
      
      def belongs_to(name, options = {})
        association(:belongs_to, name, options)
      end
      
      def has_and_belongs_to_many(name, options = {})
        association(:has_and_belongs_to_many, name, options)
      end
      
      private
      
      def association(type, name, options = {})
        field "#{name}_ids".to_sym
        self.associations[name] = options.merge(:type => type)
        define_method(name) do
          @associations ||= {}
          @associations[name] ||= Dynamoid::Associations.const_get(type.to_s.camelcase).new(self, name, options)
        end
        define_method("#{name}=".to_sym) do |objects|
          self.send(name) << objects
        end
      end
    end
    
  end
  
end
