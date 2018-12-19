# frozen_string_literal: true

module Dynamoid #:nodoc:
  module Criteria
    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it by a Query or Scan.
    class Chain
      attr_accessor :query, :source, :values, :consistent_read
      attr_reader :hash_key, :range_key, :index_name
      include Enumerable
      # Create a new criteria chain.
      #
      # @param [Class] source the class upon which the ultimate query will be performed.
      def initialize(source)
        @query = {}
        @source = source
        @consistent_read = false
        @scan_index_forward = true

        # Honor STI and :type field if it presents
        type = @source.inheritance_field
        if @source.attributes.key?(type)
          @query[:"#{type}.in"] = @source.deep_subclasses.map(&:name) << @source.name
        end
      end

      # The workhorse method of the criteria chain. Each key in the passed in hash will become another criteria that the
      # ultimate query must match. A key can either be a symbol or a string, and should be an attribute name or
      # an attribute name with a range operator.
      #
      # @example A simple criteria
      #   where(:name => 'Josh')
      #
      # @example A more complicated criteria
      #   where(:name => 'Josh', 'created_at.gt' => DateTime.now - 1.day)
      #
      # @since 0.2.0
      def where(args)
        query.update(args.dup.symbolize_keys)
        self
      end

      def consistent
        @consistent_read = true
        self
      end

      # Returns all the records matching the criteria.
      #
      # @since 0.2.0
      def all
        records
      end

      def count
        if key_present?
          count_via_query
        else
          count_via_scan
        end
      end

      # Returns the last fetched record matched the criteria
      # Enumerable doesn't implement `last`, only `first`
      # So we have to implement it ourselves
      #
      def last
        all.to_a.last
      end

      # Destroys all the records matching the criteria.
      #
      def delete_all
        ids = []
        ranges = []

        if key_present?
          Dynamoid.adapter.query(source.table_name, range_query).collect do |hash|
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym] if source.range_key
          end
        else
          Dynamoid.adapter.scan(source.table_name, scan_query, scan_opts).collect do |hash|
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym] if source.range_key
          end
        end

        Dynamoid.adapter.delete(source.table_name, ids, range_key: ranges.presence)
      end
      alias destroy_all delete_all

      # The record limit is the limit of evaluated records returned by the
      # query or scan.
      def record_limit(limit)
        @record_limit = limit
        self
      end

      # The scan limit which is the limit of records that DynamoDB will
      # internally query or scan. This is different from the record limit
      # as with filtering DynamoDB may look at N scanned records but return 0
      # records if none pass the filter.
      def scan_limit(limit)
        @scan_limit = limit
        self
      end

      def batch(batch_size)
        @batch_size = batch_size
        self
      end

      def start(start)
        @start = start
        self
      end

      def scan_index_forward(scan_index_forward)
        @scan_index_forward = scan_index_forward
        self
      end

      # Allows you to use the results of a search as an enumerable over the results found.
      #
      # @since 0.2.0
      def each(&block)
        records.each(&block)
      end

      private

      # The actual records referenced by the association.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records
        if key_present?
          records_via_query
        else
          records_via_scan
        end
      end

      def records_via_query
        Enumerator.new do |yielder|
          Dynamoid.adapter.query(source.table_name, range_query).each do |hash|
            yielder.yield source.from_database(hash)
          end
        end
      end

      # If the query does not match an index, we'll manually scan the associated table to find results.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records_via_scan
        if Dynamoid::Config.warn_on_scan && query.present?
          Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
          Dynamoid.logger.warn "You can index this query by adding index declaration to #{source.to_s.downcase}.rb:"
          Dynamoid.logger.warn "* global_secondary_index hash_key: 'some-name', range_key: 'some-another-name'"
          Dynamoid.logger.warn "* local_secondary_index range_key: 'some-name'"
          Dynamoid.logger.warn "Not indexed attributes: #{query.keys.sort.collect { |name| ":#{name}" }.join(', ')}"
        end

        Enumerator.new do |yielder|
          Dynamoid.adapter.scan(source.table_name, scan_query, scan_opts).each do |hash|
            yielder.yield source.from_database(hash)
          end
        end
      end

      def count_via_query
        Dynamoid.adapter.query_count(source.table_name, range_query)
      end

      def count_via_scan
        Dynamoid.adapter.scan_count(source.table_name, scan_query, scan_opts)
      end

      def range_hash(key)
        name, operation = key.to_s.split('.')
        val = type_cast_condition_parameter(name, query[key])

        case operation
        when 'gt'
          { range_greater_than: val }
        when 'lt'
          { range_less_than: val }
        when 'gte'
          { range_gte: val }
        when 'lte'
          { range_lte: val }
        when 'between'
          { range_between: val }
        when 'begins_with'
          { range_begins_with: val }
        end
      end

      def field_hash(key)
        name, operation = key.to_s.split('.')
        val = type_cast_condition_parameter(name, query[key])

        hash = case operation
               when 'ne'
                 { ne: val }
               when 'gt'
                 { gt: val }
               when 'lt'
                 { lt: val }
               when 'gte'
                 { gte: val }
               when 'lte'
                 { lte: val }
               when 'between'
                 { between: val }
               when 'begins_with'
                 { begins_with: val }
               when 'in'
                 { in: val }
               when 'contains'
                 { contains: val }
               when 'not_contains'
                 { not_contains: val }
               end

        { name.to_sym => hash }
      end

      def consistent_opts
        { consistent_read: consistent_read }
      end

      def range_query
        opts = {}

        # Add hash key
        opts[:hash_key] = @hash_key
        opts[:hash_value] = type_cast_condition_parameter(@hash_key, query[@hash_key])

        # Add range key
        if @range_key
          opts[:range_key] = @range_key
          if query[@range_key].present?
            value = type_cast_condition_parameter(@range_key, query[@range_key])
            opts.update(range_eq: value)
          end

          query.keys.select { |k| k.to_s =~ /^#{@range_key}\./ }.each do |key|
            opts.merge!(range_hash(key))
          end
        end

        (query.keys.map(&:to_sym) - [@hash_key.to_sym, @range_key.try(:to_sym)])
          .reject { |k, _| k.to_s =~ /^#{@range_key}\./ }
          .each do |key|
          if key.to_s.include?('.')
            opts.update(field_hash(key))
          else
            value = type_cast_condition_parameter(key, query[key])
            opts[key] = { eq: value }
          end
        end

        opts.merge(query_opts).merge(consistent_opts)
      end

      def type_cast_condition_parameter(key, value)
        return value if %i[array set].include?(source.attributes[key.to_sym][:type])

        if !value.respond_to?(:to_ary)
          options = source.attributes[key.to_sym]
          value_casted = TypeCasting.cast_field(value, options)
          Dumping.dump_field(value_casted, options)
        else
          value.to_ary.map do |el|
            options = source.attributes[key.to_sym]
            value_casted = TypeCasting.cast_field(el, options)
            Dumping.dump_field(value_casted, options)
          end
        end
      end

      def key_present?
        query_keys = query.keys.collect { |k| k.to_s.split('.').first }

        # See if querying based on table hash key
        if query.keys.map(&:to_s).include?(source.hash_key.to_s)
          @hash_key = source.hash_key

          # Use table's default range key
          if query_keys.include?(source.range_key.to_s)
            @range_key = source.range_key
            return true
          end

          # See if can use any local secondary index range key
          # Chooses the first LSI found that can be utilized for the query
          source.local_secondary_indexes.each do |_, lsi|
            next unless query_keys.include?(lsi.range_key.to_s)
            @range_key = lsi.range_key
            @index_name = lsi.name
          end

          return true
        end

        # See if can use any global secondary index
        # Chooses the first GSI found that can be utilized for the query
        # But only do so if projects ALL attributes otherwise we won't
        # get back full data
        source.global_secondary_indexes.each do |_, gsi|
          next unless query.keys.map(&:to_s).include?(gsi.hash_key.to_s) && gsi.projected_attributes == :all
          @hash_key = gsi.hash_key
          @range_key = gsi.range_key
          @index_name = gsi.name
          return true
        end

        # Could not utilize any indices so we'll have to scan
        false
      end

      # Start key needs to be set up based on the index utilized
      # If using a secondary index then we must include the index's composite key
      # as well as the tables composite key.
      def start_key
        return @start if @start.is_a?(Hash)
        hash_key = @hash_key || source.hash_key
        range_key = @range_key || source.range_key

        key = {}
        key[hash_key] = type_cast_condition_parameter(hash_key, @start.send(hash_key))
        if range_key
          key[range_key] = type_cast_condition_parameter(range_key, @start.send(range_key))
        end
        # Add table composite keys if they differ from secondary index used composite key
        if hash_key != source.hash_key
          key[source.hash_key] = type_cast_condition_parameter(source.hash_key, @start.hash_key)
        end
        if source.range_key && range_key != source.range_key
          key[source.range_key] = type_cast_condition_parameter(source.range_key, @start.range_value)
        end
        key
      end

      def query_opts
        opts = {}
        opts[:index_name] = @index_name if @index_name
        opts[:select] = 'ALL_ATTRIBUTES'
        opts[:record_limit] = @record_limit if @record_limit
        opts[:scan_limit] = @scan_limit if @scan_limit
        opts[:batch_size] = @batch_size if @batch_size
        opts[:exclusive_start_key] = start_key if @start
        opts[:scan_index_forward] = @scan_index_forward
        opts
      end

      def scan_query
        {}.tap do |opts|
          query.keys.map(&:to_sym).each do |key|
            if key.to_s.include?('.')
              opts.update(field_hash(key))
            else
              value = type_cast_condition_parameter(key, query[key])
              opts[key] = { eq: value }
            end
          end
        end
      end

      def scan_opts
        opts = {}
        opts[:record_limit] = @record_limit if @record_limit
        opts[:scan_limit] = @scan_limit if @scan_limit
        opts[:batch_size] = @batch_size if @batch_size
        opts[:exclusive_start_key] = start_key if @start
        opts[:consistent_read] = true if @consistent_read
        opts
      end
    end
  end
end
