# encoding: utf-8
module Dynamoid #:nodoc:

  module Fields
    extend ActiveSupport::Concern

    included do
      class_attribute :attributes
      
      self.attributes = {}
      field :id
      field :created_at, :datetime
      field :updated_at, :datetime
    end
    
    module ClassMethods
      def field(name, type = :string, options = {})
        named = name.to_s
        self.attributes[name] = {:type => type}.merge(options)
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
      attributes.each {|attribute, value| self.write_attribute(attribute, value)}
      save
    end

    def update_attribute(attribute, value)
      write_attribute(attribute, value)
      save
    end
    
    private
    
    def set_created_at
      self.created_at = DateTime.now
    end
    
    def set_updated_at
      self.updated_at = DateTime.now
    end
    
  end
  
end