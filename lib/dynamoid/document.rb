# encoding: utf-8
module Dynamoid #:nodoc:

  # This is the base module for all domain objects that need to be persisted to
  # the database as documents.
  module Document
    extend ActiveSupport::Concern
    include Dynamoid::Components

    attr_reader :new_record
    
    def initialize(attrs = {}, options = nil)
      @new_record = true
      @attributes ||= {}
      self.class.attributes.each {|att| write_attribute(att, attrs[att])}
    end
    
  end
  
end