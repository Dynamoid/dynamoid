# encoding: utf-8
module Dynamoid

  # This module defines the finder methods that hang off the document at the
  # class level, like find, find_by_id, and the method_missing style finders.
  module Finders
    extend ActiveSupport::Concern

    RANGE_MAP = {
      'gt'            => :range_greater_than,
      'lt'            => :range_less_than,
      'gte'           => :range_gte,
      'lte'           => :range_lte,
      'begins_with'   => :range_begins_with,
      'between'       => :range_between,
      'eq'            => :range_eq
    }

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
        expects_array = ids.first.kind_of?(Array)

        ids = Array(ids.flatten.uniq)
        if ids.count == 1
          result = self.find_by_id(ids.first, options)
          expects_array ? Array(result) : result
        else
          find_all(ids)
        end
      end

      # Return objects found by the given array of ids, either hash keys, or hash/range key combinations using BatchGet.
      # Returns empty array if no results found.
      #
      # @param [Array<ID>] ids
      # @param [Hash] options: Passed to the underlying query.
      #
      # @example
      #   find all the user with hash key
      #   User.find_all(['1', '2', '3'])
      #
      #   find all the tweets using hash key and range key with consistent read
      #   Tweet.find_all([['1', 'red'], ['1', 'green']], :consistent_read => true)
      def find_all(ids, options = {})
        items = Dynamoid.adapter.read(self.table_name, ids, options)
        items ? items[self.table_name].map{|i| from_database(i)} : []
      end

      # Find one object directly by id.
      #
      # @param [String] id the id of the object to find
      #
      # @return [Dynamoid::Document] the found object, or nil if nothing was found
      #
      # @since 0.2.0
      def find_by_id(id, options = {})
        if item = Dynamoid.adapter.read(self.table_name, id, options)
          from_database(item)
        else
          nil
        end
      end

      # Find one object directly by hash and range keys
      #
      # @param [String] hash_key of the object to find
      # @param [String/Number] range_key of the object to find
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
        Dynamoid.adapter.query(self.table_name, options.merge({hash_value: hash_key})).collect do |item|
          from_database(item)
        end
      end

      # Find all objects by using local secondary or global secondary index
      #
      # @example
      #   class User
      #     include Dynamoid::Document
      #     field :email,          :string
      #     field :age,            :integer
      #     field :gender,         :string
      #     field :rank            :number
      #     table :key => :email
      #     global_secondary_index :hash_key => :age, :range_key => :gender
      #   end
      #   User.find_all_by_secondary_index(:age => 5, :range => {"rank.lte" => 10})
      #
      # @param [Hash] eg: {:age => 5}
      # @param [Hash] eg: {"rank.lte" => 10}
      # @param [Hash] options - @TODO support more options in future such as
      #               query filter, projected keys etc
      # @return [Array] an array of all matching items
      def find_all_by_secondary_index(hash, options = {})
        range = options[:range] || {}
        hash_key_field, hash_key_value = hash.first
        range_key_field, range_key_value = range.first
        range_op_mapped = nil

        if range_key_field
          range_key_field = range_key_field.to_s
          range_key_op = "eq"
          if range_key_field.include?(".")
            range_key_field, range_key_op = range_key_field.split(".", 2)
          end
          range_op_mapped = RANGE_MAP.fetch(range_key_op)
        end

        # Find the index
        index = self.find_index(hash_key_field, range_key_field)
        raise Dynamoid::Errors::MissingIndex if index.nil?

        # query
        opts = {
          :hash_key => hash_key_field.to_s,
          :hash_value => hash_key_value,
          :index_name => index.name,
        }

        opts[:select] = options[:select] if options[:select].present?
        opts[:batch_size] = options[:batch_size] if options[:batch_size].present?

        if range_key_field
          opts[:range_key] = range_key_field
          opts[range_op_mapped] = range_key_value
        end
        Dynamoid.adapter.query(self.table_name, opts).map do |item|
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
