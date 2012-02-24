require 'digest/sha2'

# encoding: utf-8
module Dynamoid #:nodoc:

  # Associate a document with another object: belongs_to, has_many, and has_and_belongs_to_many
  module Relations
    extend ActiveSupport::Concern

    included do
      class_attribute :indexes
      
      self.indexes = []
    end
    
    module ClassMethods

    end
  end
  
end