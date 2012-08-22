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
          find_all(ids)
        end
      end

      # Find all object by hash key or hash and range key
      #
      # @param [Array<ID>] ids
      #
      # @example
      #   find all the user with hash key
      #   User.find_all(['1', '2', '3'])
      #
      #   find all the tweets using hash key and range key
      #   Tweet.find_all([['1', 'red'], ['1', 'green'])
      def find_all(ids)
        items = Dynamoid::Adapter.read(self.table_name, ids, options)
        items[self.table_name].collect{|i| from_database(i) }
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
          from_database(item)
        else
          nil
        end
      end

      # Find one object directly by hash and range keys
      #
      # @param [String] hash_key of the object to find
      # @param [String/Integer/Float] range_key of the object to find
      #
      def find_by_composite_key(hash_key, range_key, options = {})
        find_by_id(hash_key, options.merge({:range_key => range_key}))
      end

      # Find all objects by hash and range keys.
      #
      # @example find all ChamberTypes whose level is greater than 1
      #   class ChamberType
      #     include Dynamoid::Document
      #     field :chamber_type,            :string
      #     range :level,                   :integer
      #     table :key => :chamber_type
      #   end
      #   ChamberType.find_all_by_composite_key('DustVault', range_greater_than: 1)
      #
      # @param [String] hash_key of the objects to find
      # @param [Hash] options the options for the range key
      # @option options [Range] :range_value find the range key within this range
      # @option options [Number] :range_greater_than find range keys greater than this
      # @option options [Number] :range_less_than find range keys less than this
      # @option options [Number] :range_gte find range keys greater than or equal to this
      # @option options [Number] :range_lte find range keys less than or equal to this
      #
      # @return [Array] an array of all matching items
      #
      def find_all_by_composite_key(hash_key, options = {})
        Dynamoid::Adapter.query(self.table_name, options.merge({hash_value: hash_key})).collect do |item|
          from_database(item)
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
