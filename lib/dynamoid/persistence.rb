require 'securerandom'

# encoding: utf-8
module Dynamoid #:nodoc:

  # This module saves things!
  module Persistence
    extend ActiveSupport::Concern
    
    def save
      self.class.create_table unless Dynamoid::Adapter.list_tables.include?(self.class.table_name)
      self.id = SecureRandom.uuid if self.id.nil? || self.id.blank?
      Dynamoid::Adapter.put_item(self.class.table_name, self.attributes)
    end
    
    module ClassMethods
      def table_name
        "#{Dynamoid::Config.namespace}_#{self.to_s.downcase.pluralize}"
      end
      
      def create_table
        Dynamoid::Adapter.create_table(table_name, :id)
      end
    end
  end
  
end