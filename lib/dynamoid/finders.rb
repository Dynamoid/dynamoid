# frozen_string_literal: true

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
    }.freeze

    module ClassMethods
      # Find one or many objects, specified by one id or an array of ids.
      #
      # @param [Array/String] *id an array of ids or one single id
      # @param [Hash] options
      #
      # @return [Dynamoid::Document] one object or an array of objects, depending on whether the input was an array or not
      #
      # @example Find by partition key
      #   Document.find(101)
      #
      # @example Find by partition key and sort key
      #   Document.find(101, range_key: 'archived')
      #
      # @example Find several documents by partition key
      #   Document.find(101, 102, 103)
      #   Document.find([101, 102, 103])
      #
      # @example Find several documents by partition key and sort key
      #   Document.find([[101, 'archived'], [102, 'new'], [103, 'deleted']])
      #
      # @since 0.2.0
      def find(*ids, **options)
        if ids.size == 1 && !ids[0].is_a?(Array)
          _find_by_id(ids[0], options.merge(raise_error: true))
        else
          _find_all(ids.flatten(1), raise_error: true)
        end
      end

      # Return objects found by the given array of ids, either hash keys, or hash/range key combinations using BatchGetItem.
      # Returns empty array if no results found.
      #
      # Uses backoff specified by `Dynamoid::Config.backoff` config option
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
        ActiveSupport::Deprecation.warn('[Dynamoid] .find_all is deprecated! Call .find instead of')

        _find_all(ids, options)
      end

      # Find one object directly by id.
      #
      # @param [String] id the id of the object to find
      #
      # @return [Dynamoid::Document] the found object, or nil if nothing was found
      #
      # @example Find by partition key
      #   Document.find_by_id(101)
      #
      # @example Find by partition key and sort key
      #   Document.find_by_id(101, range_key: 'archived')
      #
      # @since 0.2.0
      def find_by_id(id, options = {})
        ActiveSupport::Deprecation.warn('[Dynamoid] .find_by_id is deprecated! Call .find instead of', caller[1..-1])

        _find_by_id(id, options)
      end

      def _find_all(ids, options = {})
        if range_key
          ids = ids.map do |pk, sk|
            sk_casted = TypeCasting.cast_field(sk, attributes[range_key])
            sk_dumped = Dumping.dump_field(sk_casted, attributes[range_key])

            [pk, sk_dumped]
          end
        end

        items = if Dynamoid.config.backoff
                  items = []
                  backoff = nil
                  Dynamoid.adapter.read(table_name, ids, options) do |hash, has_unprocessed_items|
                    items += hash[table_name]

                    if has_unprocessed_items
                      backoff ||= Dynamoid.config.build_backoff
                      backoff.call
                    else
                      backoff = nil
                    end
                  end
                  items
                else
                  items = Dynamoid.adapter.read(table_name, ids, options)
                  items ? items[table_name] : []
                end

        if items.size == ids.size || !options[:raise_error]
          items ? items.map { |i| from_database(i) } : []
        else
          message = "Couldn't find all #{name.pluralize} with '#{hash_key}': (#{ids.join(', ')}) "
          message += "(found #{items.size} results, but was looking for #{ids.size})"
          raise Errors::RecordNotFound, message
        end
      end

      def _find_by_id(id, options = {})
        if range_key
          key = options[:range_key]
          key_casted = TypeCasting.cast_field(key, attributes[range_key])
          key_dumped = Dumping.dump_field(key_casted, attributes[range_key])

          options[:range_key] = key_dumped
        end

        if item = Dynamoid.adapter.read(table_name, id, options)
          from_database(item)
        elsif options[:raise_error]
          message = "Couldn't find #{name} with '#{hash_key}'=#{id}"
          raise Errors::RecordNotFound, message
        end
      end

      # Find one object directly by hash and range keys
      #
      # @param [String] hash_key of the object to find
      # @param [String/Number] range_key of the object to find
      #
      def find_by_composite_key(hash_key, range_key, options = {})
        ActiveSupport::Deprecation.warn('[Dynamoid] .find_by_composite_key is deprecated! Call .find instead of')

        _find_by_id(hash_key, options.merge(range_key: range_key))
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
      def find_all_by_composite_key(hash_key, options = {})
        ActiveSupport::Deprecation.warn('[Dynamoid] .find_all_composite_key is deprecated! Call .where instead of')

        Dynamoid.adapter.query(table_name, options.merge(hash_value: hash_key)).collect do |item|
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
      #     global_secondary_index :hash_key => :age, :range_key => :rank
      #   end
      #   # NOTE: the first param and the second param are both hashes,
      #   #       so curly braces must be used on first hash param if sending both params
      #   User.find_all_by_secondary_index({:age => 5}, :range => {"rank.lte" => 10})
      #
      # @param [Hash] eg: {:age => 5}
      # @param [Hash] eg: {"rank.lte" => 10}
      # @param [Hash] options - query filter, projected keys, scan_index_forward etc
      # @return [Array] an array of all matching items
      def find_all_by_secondary_index(hash, options = {})
        ActiveSupport::Deprecation.warn('[Dynamoid] .find_all_by_secondary_index is deprecated! Call .where instead of')

        range = options[:range] || {}
        hash_key_field, hash_key_value = hash.first
        range_key_field, range_key_value = range.first
        range_op_mapped = nil

        if range_key_field
          range_key_field = range_key_field.to_s
          range_key_op = 'eq'
          if range_key_field.include?('.')
            range_key_field, range_key_op = range_key_field.split('.', 2)
          end
          range_op_mapped = RANGE_MAP.fetch(range_key_op)
        end

        # Find the index
        index = find_index(hash_key_field, range_key_field)
        raise Dynamoid::Errors::MissingIndex, "attempted to find #{[hash_key_field, range_key_field]}" if index.nil?

        # query
        opts = {
          hash_key: hash_key_field.to_s,
          hash_value: hash_key_value,
          index_name: index.name
        }
        if range_key_field
          opts[:range_key] = range_key_field
          opts[range_op_mapped] = range_key_value
        end
        dynamo_options = opts.merge(options.reject { |key, _| key == :range })
        Dynamoid.adapter.query(table_name, dynamo_options).map do |item|
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
          ActiveSupport::Deprecation.warn("[Dynamoid] .#{method} is deprecated! Call .where instead of")

          finder = method.to_s.split('_by_').first
          attributes = method.to_s.split('_by_').last.split('_and_')

          chain = Dynamoid::Criteria::Chain.new(self)
          chain.query = {}.tap { |h| attributes.each_with_index { |attr, index| h[attr.to_sym] = args[index] } }

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
