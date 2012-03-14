# encoding: utf-8
require 'dynamoid/indexes/index'

module Dynamoid #:nodoc:

  # Builds all indexes present on the model.
  module Indexes
    extend ActiveSupport::Concern

    included do
      class_attribute :indexes
      
      self.indexes = {}
    end
    
    module ClassMethods
      def index(name, options = {})
        index = Dynamoid::Indexes::Index.new(self, name, options)
        self.indexes[index.name] = index
        create_indexes        
      end
      
      def find_index(index)
        self.indexes[Array(index).collect(&:to_s).sort.collect(&:to_sym)]
      end
      
      def create_indexes
        self.indexes.each do |name, index|
          opts = index.range_key? ? {:range_key => :range} : {}
          self.create_table(index.table_name, :id, opts) unless self.table_exists?(index.table_name)
        end
      end
    end
    
    def save_indexes
      self.class.indexes.each do |name, index|
        index.save(self)
      end
    end
    
    def delete_indexes
      self.class.indexes.each do |name, index|
        index.delete(self)
      end
    end
  end
  
end
