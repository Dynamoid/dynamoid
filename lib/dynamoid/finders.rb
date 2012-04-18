# encoding: utf-8
module Dynamoid

  # This module defines the finder methods that hang off the document at the
  # class level, like find, find_by_id, and the method_missing style finders.
  module Finders
    extend ActiveSupport::Concern
    
    module ClassMethods
      
      # Find one or many objects, specified by one id or an array of ids.
      #
      # @param [Array/String] *id an array of ids or one single id
      #
      # @return [Dynamoid::Document] one object or an array of objects, depending on whether the input was an array or not
      #
      # @since 0.2.0
      def find(*ids)

        options = if ids.last.is_a? Hash
                    ids.slice!(-1)
                  else
                    {}
                  end

        ids = Array(ids.flatten.uniq)
        if ids.count == 1
          self.find_by_id(ids.first, options)
        else
          items = Dynamoid::Adapter.read(self.table_name, ids, options)
          items[self.table_name].collect{|i| self.build(i).tap { |o| o.new_record = false } }
        end
      end

      # Find one object directly by id.
      #
      # @param [String] id the id of the object to find
      #
      # @return [Dynamoid::Document] the found object, or nil if nothing was found
      #
      # @since 0.2.0      
      def find_by_id(id, options = {})
        if item = Dynamoid::Adapter.read(self.table_name, id, options)
          obj = self.new(item)
          obj.new_record = false
          return obj
        else
          return nil
        end
      end

      # Find using exciting method_missing finders attributes. Uses criteria chains under the hood to accomplish this neatness.
      #
      # @example find a user by a first name
      #   User.find_by_first_name('Josh')
      #
      # @example find all users by first and last name
      #   User.find_all_by_first_name_and_last_name('Josh', 'Symonds')
      #
      # @return [Dynamoid::Document/Array] the found object, or an array of found objects if all was somewhere in the method
      #
      # @since 0.2.0            
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
