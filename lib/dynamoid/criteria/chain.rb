# frozen_string_literal: true

require_relative 'key_fields_detector'
require_relative 'nonexistent_fields_detector'

module Dynamoid #:nodoc:
  module Criteria
    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it by a Query or Scan.
    class Chain
      attr_reader :query, :source, :consistent_read, :key_fields_detector

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

        # we should re-initialize keys detector every time we change query
        @key_fields_detector = KeyFieldsDetector.new(@query, @source)
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
        query.update(args.symbolize_keys)

        nonexistent_fields = NonexistentFieldsDetector.new(args, @source).fields

        if nonexistent_fields.present?
          fields_list = nonexistent_fields.map { |s| "`#{s}`" }.join(', ')
          fields_count = nonexistent_fields.size

          Dynamoid.logger.warn(
            "where conditions contain nonexistent" \
            " field #{ 'name'.pluralize(fields_count) } #{ fields_list }"
          )
        end

        # we should re-initialize keys detector every time we change query
        @key_fields_detector = KeyFieldsDetector.new(@query, @source)

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
        if @key_fields_detector.key_present?
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

        if @key_fields_detector.key_present?
          Dynamoid.adapter.query(source.table_name, range_query).flat_map{ |i| i }.collect do |hash|
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym] if source.range_key
          end
        else
          Dynamoid.adapter.scan(source.table_name, scan_query, scan_opts).flat_map{ |i| i }.collect do |hash|
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

      def find_by_pages(&block)
        pages.each(&block)
      end

      private

      # The actual records referenced by the association.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records
        pages.lazy.flat_map { |i| i }
      end

      # Arrays of records, sized based on the actual pages produced by DynamoDB
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 3.1.0
      def pages
        if @key_fields_detector.key_present?
          pages_via_query
        else
          issue_scan_warning if Dynamoid::Config.warn_on_scan && query.present?
          pages_via_scan
        end
      end

      # If the query matches an index, we'll query the associated table to find results.
      #
      # @return [Enumerator] an iterator of the found pages. An array of records
      #
      # @since 3.1.0
      def pages_via_query
        Enumerator.new do |yielder|
          Dynamoid.adapter.query(source.table_name, range_query).each do |items, metadata|
            yielder.yield items.map { |hash| source.from_database(hash) }, metadata.slice(:last_evaluated_key)
          end
        end
      end

      # If the query does not match an index, we'll manually scan the associated table to find results.
      #
      # @return [Enumerator] an iterator of the found pages. An array of records
      #
      # @since 3.1.0
      def pages_via_scan
        Enumerator.new do |yielder|
          Dynamoid.adapter.scan(source.table_name, scan_query, scan_opts).each do |items, metadata|
            yielder.yield(items.map { |hash| source.from_database(hash) }, metadata.slice(:last_evaluated_key))
          end
        end
      end

      def issue_scan_warning
        Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
        Dynamoid.logger.warn "You can index this query by adding index declaration to #{source.to_s.downcase}.rb:"
        Dynamoid.logger.warn "* global_secondary_index hash_key: 'some-name', range_key: 'some-another-name'"
        Dynamoid.logger.warn "* local_secondary_index range_key: 'some-name'"
        Dynamoid.logger.warn "Not indexed attributes: #{query.keys.sort.collect { |name| ":#{name}" }.join(', ')}"
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
        opts[:hash_key] = @key_fields_detector.hash_key
        opts[:hash_value] = type_cast_condition_parameter(@key_fields_detector.hash_key, query[@key_fields_detector.hash_key])

        # Add range key
        if @key_fields_detector.range_key
          opts[:range_key] = @key_fields_detector.range_key
          if query[@key_fields_detector.range_key].present?
            value = type_cast_condition_parameter(@key_fields_detector.range_key, query[@key_fields_detector.range_key])
            opts.update(range_eq: value)
          end

          query.keys.select { |k| k.to_s =~ /^#{@key_fields_detector.range_key}\./ }.each do |key|
            opts.merge!(range_hash(key))
          end
        end

        (query.keys.map(&:to_sym) - [@key_fields_detector.hash_key.to_sym, @key_fields_detector.range_key.try(:to_sym)])
          .reject { |k, _| k.to_s =~ /^#{@key_fields_detector.range_key}\./ }
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

      # Start key needs to be set up based on the index utilized
      # If using a secondary index then we must include the index's composite key
      # as well as the tables composite key.
      def start_key
        return @start if @start.is_a?(Hash)

        hash_key = @key_fields_detector.hash_key || source.hash_key
        range_key = @key_fields_detector.range_key || source.range_key

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
        opts[:index_name] = @key_fields_detector.index_name if @key_fields_detector.index_name
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
