# encoding: utf-8
module Dynamoid #:nodoc:

  # This module defines the finder methods that hang off the document at the
  # class level.
  module Finders
    extend ActiveSupport::Concern
    
    module ClassMethods
      def find(*id)
        id = Array(id.flatten.uniq)
        if id.count == 1
          self.find_by_id(id.first)
        else
          items = Dynamoid::Adapter.read(self.table_name, id)
          items[self.table_name].collect{|i| self.build(i).tap { |o| o.new_record = false } }
        end
      end
      
      def find_by_id(id)
        if item = Dynamoid::Adapter.read(self.table_name, id)
          obj = self.new(item)
          obj.new_record = false
          return obj
        else
          return nil
        end
      end
      
      def method_missing(method, *args)
        if method =~ /find/
          finder = method.to_s.split('_by_').first
          attributes = method.to_s.split('_by_').last.split('_and_')

          chain = Dynamoid::Criteria::Chain.new(self)
          chain.query = Hash.new.tap {|h| attributes.each_with_index {|attr, index| h[attr.to_sym] = args[index]}}
          
          if finder =~ /all/
            return chain.all
          else
            return chain.first
          end
        else
          super
        end
      end
    end
  end
  
end
