# frozen_string_literal: true

module Dynamoid
  # This module defines the finder methods that hang off the document at the
  # class level, like find, find_by_id, and the method_missing style finders.
  module Finders
    extend ActiveSupport::Concern

    module ClassMethods
      # Find one or many objects, specified by one id or an array of ids.
      #
      # By default it raises +RecordNotFound+ exception if at least one model
      # isn't found. This behavior can be changed with +raise_error+ option. If
      # specified +raise_error: false+ option then +find+ will not raise the
      # exception.
      #
      # When a document schema includes range key it should always be specified
      # in +find+ method call. In case it's missing +MissingRangeKey+ exception
      # will be raised.
      #
      # Please note that +find+ doesn't preserve order of models in result when
      # given multiple ids.
      #
      # Supported following options:
      # * +consistent_read+
      # * +range_key+
      # * +raise_error+
      #
      # @param ids [String|Array] hash key or an array of hash keys
      # @param options [Hash]
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
      # @example Perform strong consistent reads
      #   Document.find(101, consistent_read: true)
      #   Document.find(101, 102, 103, consistent_read: true)
      #   Document.find(101, range_key: 'archived', consistent_read: true)
      #
      # @since 0.2.0
      def find(*ids, **options)
        if ids.size == 1 && !ids[0].is_a?(Array)
          _find_by_id(ids[0], options.reverse_merge(raise_error: true))
        else
          _find_all(ids.flatten(1), options.reverse_merge(raise_error: true))
        end
      end

      # Find several models at once.
      #
      # Returns objects found by the given array of ids, either hash keys, or
      # hash/range key combinations using +BatchGetItem+.
      #
      # Returns empty array if no results found.
      #
      # Uses backoff specified by +Dynamoid::Config.backoff+ config option.
      #
      # @param ids [Array] array of primary keys
      # @param options [Hash]
      # @option options [true|false] :consistent_read
      # @option options [true|false] :raise_error
      #
      # @example
      #   # Find all the user with hash key
      #   User.find_all(['1', '2', '3'])
      #
      #   # Find all the tweets using hash key and range key with consistent read
      #   Tweet.find_all([['1', 'red'], ['1', 'green']], consistent_read: true)
      def find_all(ids, options = {})
        Dynamoid.deprecator.warn('[Dynamoid] .find_all is deprecated! Call .find instead of')

        _find_all(ids, options)
      end

      # Find one object directly by primary key.
      #
      # @param id [String] the id of the object to find
      # @param options [Hash]
      # @option options [true|false] :consistent_read
      # @option options [true|false] :raise_error
      # @option options [Scalar value] :range_key
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
        Dynamoid.deprecator.warn('[Dynamoid] .find_by_id is deprecated! Call .find instead of')

        _find_by_id(id, options)
      end

      # @private
      def _find_all(ids, options = {})
        ids = ids.map do |id|
          if range_key
            # expect [hash key, range key] pair
            pk, sk = id

            if pk.nil?
              raise Errors::MissingHashKey
            end
            if sk.nil?
              raise Errors::MissingRangeKey
            end

            pk_dumped = cast_and_dump(hash_key, pk)
            sk_dumped = cast_and_dump(range_key, sk)

            [pk_dumped, sk_dumped]
          else
            if id.nil?
              raise Errors::MissingHashKey
            end

            cast_and_dump(hash_key, id)
          end
        end

        read_options = options.slice(:consistent_read)

        items = if Dynamoid.config.backoff
                  items = []
                  backoff = nil
                  Dynamoid.adapter.read(table_name, ids, read_options) do |hash, has_unprocessed_items|
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
                  items = Dynamoid.adapter.read(table_name, ids, read_options)
                  items ? items[table_name] : []
                end

        if items.size == ids.size || !options[:raise_error]
          models = items ? items.map { |i| from_database(i) } : []
          models.each { |m| m.run_callbacks :find }
          models
        else
          ids_list = range_key ? ids.map { |pk, sk| "(#{pk.inspect},#{sk.inspect})" } : ids.map(&:inspect)
          message = "Couldn't find all #{name.pluralize} with primary keys [#{ids_list.join(', ')}] "
          message += "(found #{items.size} results, but was looking for #{ids.size})"
          raise Errors::RecordNotFound, message
        end
      end

      # @private
      def _find_by_id(id, options = {})
        raise Errors::MissingHashKey if id.nil?
        raise Errors::MissingRangeKey if range_key && options[:range_key].nil?

        partition_key_dumped = cast_and_dump(hash_key, id)

        if range_key
          options[:range_key] = cast_and_dump(range_key, options[:range_key])
        end

        if item = Dynamoid.adapter.read(table_name, partition_key_dumped, options.slice(:range_key, :consistent_read))
          model = from_database(item)
          model.run_callbacks :find
          model
        elsif options[:raise_error]
          primary_key = range_key ? "(#{id.inspect},#{options[:range_key].inspect})" : id.inspect
          message = "Couldn't find #{name} with primary key #{primary_key}"
          raise Errors::RecordNotFound, message
        end
      end

      # Find one object directly by hash and range keys.
      #
      # @param hash_key [Scalar value] hash key of the object to find
      # @param range_key [Scalar value] range key of the object to find
      #
      def find_by_composite_key(hash_key, range_key, options = {})
        Dynamoid.deprecator.warn('[Dynamoid] .find_by_composite_key is deprecated! Call .find instead of')

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
      #
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
        Dynamoid.deprecator.warn('[Dynamoid] .find_all_composite_key is deprecated! Call .where instead of')

        Dynamoid.adapter.query(table_name, options.merge(hash_value: hash_key)).flat_map { |i| i }.collect do |item|
          from_database(item)
        end
      end

      # Find all objects by using local secondary or global secondary index
      #
      # @example
      #   class User
      #     include Dynamoid::Document
      #
      #     table :key => :email
      #     global_secondary_index hash_key: :age, range_key: :rank
      #
      #     field :email,  :string
      #     field :age,    :integer
      #     field :gender, :string
      #     field :rank    :number
      #   end
      #
      #   # NOTE: the first param and the second param are both hashes,
      #   #       so curly braces must be used on first hash param if sending both params
      #   User.find_all_by_secondary_index({ age: 5 }, range: { "rank.lte": 10 })
      #
      # @param hash [Hash] conditions for the hash key e.g. +{ age: 5 }+
      # @param options [Hash] conditions on range key e.g. +{ "rank.lte": 10 }, query filter, projected keys, scan_index_forward etc.
      # @return [Array] an array of all matching items
      def find_all_by_secondary_index(hash, options = {})
        Dynamoid.deprecator.warn('[Dynamoid] .find_all_by_secondary_index is deprecated! Call .where instead of')

        range = options[:range] || {}
        hash_key_field, hash_key_value = hash.first
        range_key_field, range_key_value = range.first

        if range_key_field
          range_key_field = range_key_field.to_s
          range_key_op = 'eq'
          if range_key_field.include?('.')
            range_key_field, range_key_op = range_key_field.split('.', 2)
          end
        end

        # Find the index
        index = find_index(hash_key_field, range_key_field)
        raise Dynamoid::Errors::MissingIndex, "attempted to find #{[hash_key_field, range_key_field]}" if index.nil?

        # Query
        query_key_conditions = {}
        query_key_conditions[hash_key_field.to_sym] = [[:eq, hash_key_value]]
        if range_key_field
          query_key_conditions[range_key_field.to_sym] = [[range_key_op.to_sym, range_key_value]]
        end

        query_non_key_conditions = options
          .except(*Dynamoid::AdapterPlugin::AwsSdkV3::Query::OPTIONS_KEYS)
          .except(:range)
          .symbolize_keys

        query_options = options.slice(*Dynamoid::AdapterPlugin::AwsSdkV3::Query::OPTIONS_KEYS)
        query_options[:index_name] = index.name

        Dynamoid.adapter.query(table_name, query_key_conditions, query_non_key_conditions, query_options)
          .flat_map { |i| i }
          .map { |item| from_database(item) }
      end

      # Find using exciting method_missing finders attributes. Uses criteria
      # chains under the hood to accomplish this neatness.
      #
      # @example find a user by a first name
      #   User.find_by_first_name('Josh')
      #
      # @example find all users by first and last name
      #   User.find_all_by_first_name_and_last_name('Josh', 'Symonds')
      #
      # @return [Dynamoid::Document|Array] the found object, or an array of found objects if all was somewhere in the method
      #
      # @private
      # @since 0.2.0
      def method_missing(method, *args)
        # Cannot use Symbol#start_with? because it was introduced in Ruby 2.7, but we support Ruby >= 2.3
        if method.to_s.start_with?('find')
          Dynamoid.deprecator.warn("[Dynamoid] .#{method} is deprecated! Call .where instead of")

          finder = method.to_s.split('_by_').first
          attributes = method.to_s.split('_by_').last.split('_and_')

          chain = Dynamoid::Criteria::Chain.new(self)
          chain = chain.where({}.tap { |h| attributes.each_with_index { |attr, index| h[attr.to_sym] = args[index] } })

          if finder.include?('all')
            chain.all
          else
            chain.first
          end
        else
          super
        end
      end

      private

      def cast_and_dump(name, value)
        attribute_options = attributes[name]
        casted_value = TypeCasting.cast_field(value, attribute_options)
        Dumping.dump_field(casted_value, attribute_options)
      end
    end
  end
end
