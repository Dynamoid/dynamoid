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
          id.collect {|id| self.find_by_id(id)}
        end
      end
      
      def find_by_id(id)
        obj = self.new(Dynamoid::Adapter.get_item(self.table_name, id))
        obj.new_record = false
        obj        
      end
      
      def method_missing(method, *args)
        if method =~ /find/
          finder = method.to_s.split('_by_').first
          attributes = method.to_s.split('_by_').last.split('_and_')
          
          results = if index = self.indexes.find {|i| i == attributes.sort.collect(&:to_sym)}
            ids = Dynamoid::Adapter.get_item(self.index_table_name(index), self.key_for_index(index, args))
            if ids.nil? || ids.empty?
              []
            else
              self.find(ids[:ids])
            end
          else
            puts 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
            puts "You can index this query by adding this to #{self.to_s.downcase}.rb: index [#{attributes.sort.collect{|attr| ":#{attr}"}.join(', ')}]"
            scan_hash = {}
            attributes.each_with_index {|attr, index| scan_hash[attr.to_sym] = args[index]}
            Dynamoid::Adapter.scan(self.table_name, scan_hash).collect {|hash| self.new(hash)}
          end
          
          if finder =~ /all/
            return Array(results)
          else
            return results.first
          end
        end
      end
    end
  end
  
end