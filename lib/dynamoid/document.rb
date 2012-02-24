# encoding: utf-8
module Dynamoid #:nodoc:

  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components

    attr_accessor :new_record
    
    def initialize(attrs = {})
      @new_record = true
      @attributes ||= {}
      self.class.attributes.each {|att| write_attribute(att, attrs[att])}
    end
    
    def ==(other)
      other.respond_to?(:id) && other.id == self.id
    end
    
    module ClassMethods
      def create(attrs = {})
        obj = self.new(attrs)
        obj.save && obj.new_record = false
        obj
      end
      
      def build(attrs = {})
        self.new(attrs)
      end
    end
  end
  
end