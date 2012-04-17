# encoding: utf-8
require 'dynamoid/indexes/index'

module Dynamoid #:nodoc:

  # Indexes are quick ways of performing queries by anything other than id in DynamoDB. They are denormalized tables; 
  # that is, data is duplicated in the initial table (where the object is saved) and the index table (where 
  # we perform indexing). 
  module Indexes
    extend ActiveSupport::Concern

    # Make some helpful attributes to persist indexes.
    included do
      class_attribute :indexes
      
      self.indexes = {}
    end
    
    module ClassMethods
      
      # The call to create an index. Generates a new index with the specified options -- for more information, see Dynamoid::Indexes::Index.
      # This function also attempts to immediately create the indexing table if it does not exist already.
      #
      # @since 0.2.0
      def index(name, options = {})
        index = Dynamoid::Indexes::Index.new(self, name, options)
        self.indexes[index.name] = index
        create_indexes        
      end
      
      # Helper function to find indexes.
      #
      # @since 0.2.0
      def find_index(index)
        self.indexes[Array(index).collect(&:to_s).sort.collect(&:to_sym)]
      end
      
      # Helper function to create indexes (if they don't exist already).
      #
      # @since 0.2.0
      def create_indexes
        self.indexes.each do |name, index|
          opts = index.range_key? ? {:range_key => { :range => :number }} : {}
          self.create_table(index.table_name, :id, opts) unless self.table_exists?(index.table_name)
        end
      end
    end
    
    # Callback for an object to save itself to each of a class' indexes.
    #
    # @since 0.2.0
    def save_indexes
      self.class.indexes.each do |name, index|
        index.save(self)
      end
    end

    # Callback for an object to delete itself from each of a class' indexes.
    #
    # @since 0.2.0    
    def delete_indexes
      self.class.indexes.each do |name, index|
        index.delete(self)
      end
    end
  end
  
end
