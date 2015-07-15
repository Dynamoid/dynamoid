# encoding: utf-8
module Dynamoid #:nodoc:
  module Criteria

    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it by a Query or Scan.
    class Chain
      attr_accessor :query, :source, :values, :consistent_read
      include Enumerable

      # Create a new criteria chain.
      #
      # @param [Class] source the class upon which the ultimate query will be performed.
      def initialize(source)
        @query = {}
        @source = source
        @consistent_read = false
        @scan_index_forward = true
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
        args.each {|k, v| query[k.to_sym] = v}
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

      # Destroys all the records matching the criteria.
      #
      def destroy_all
        ids = []
        
        if key_present?
          ranges = []
          Dynamoid::Adapter.query(source.table_name, range_query).collect do |hash| 
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym]
          end
          
          Dynamoid::Adapter.delete(source.table_name, ids,{:range_key => ranges})
        else
          Dynamoid::Adapter.scan(source.table_name, query, scan_opts).collect do |hash| 
            ids << hash[source.hash_key.to_sym]
          end
          
          Dynamoid::Adapter.delete(source.table_name, ids)
        end   
      end

      def eval_limit(limit)
        @eval_limit = limit
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

      def consistent_opts
        { :consistent_read => consistent_read }
      end

      private

      # The actual records referenced by the association.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records
        results = if key_present?
          records_via_query
        else
          records_via_scan
        end
        @batch_size ? results : Array(results)
      end

      def records_via_query
        Enumerator.new do |yielder|
          Dynamoid::Adapter.query(source.table_name, range_query).each do |hash|
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
        if Dynamoid::Config.warn_on_scan
          Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
          Dynamoid.logger.warn "You can index this query by adding this to #{source.to_s.downcase}.rb: index [#{source.attributes.sort.collect{|attr| ":#{attr}"}.join(', ')}]"
        end

        if @consistent_read
          raise Dynamoid::Errors::InvalidQuery, 'Consistent read is not supported by SCAN operation'
        end

        Enumerator.new do |yielder|
          Dynamoid::Adapter.scan(source.table_name, query, scan_opts).each do |hash|
            yielder.yield source.from_database(hash)
          end
        end
      end

      def range_hash(key)
        val = query[key]

        return { :range_value => query[key] } if query[key].is_a?(Range)

        case key.to_s.split('.').last
        when 'gt'
          { :range_greater_than => val.to_f }
        when 'lt'
          { :range_less_than  => val.to_f }
        when 'gte'
          { :range_gte  => val.to_f }
        when 'lte'
          { :range_lte => val.to_f }
        when 'begins_with'
          { :range_begins_with => val }
        end
      end

      def range_query
        opts = { :hash_value => query[source.hash_key] }
        if key = query.keys.find { |k| k.to_s.include?('.') }
          opts.merge!(range_hash(key))
        end
        opts.merge(query_opts).merge(consistent_opts)
      end

      def query_keys
        query.keys.collect{|k| k.to_s.split('.').first}
      end

      # [hash_key] or [hash_key, range_key] is specified in query keys.
      def key_present?
        query_keys == [source.hash_key.to_s] || (query_keys.to_set == [source.hash_key.to_s, source.range_key.to_s].to_set)
      end

      def start_key
        key = { :hash_key_element => @start.hash_key }
        if range_key = @start.class.range_key
          key.merge!({:range_key_element => @start.send(range_key) })
        end
        key
      end

      def query_opts
        opts = {}
        opts[:select] = 'ALL_ATTRIBUTES'
        opts[:limit] = @eval_limit if @eval_limit
        opts[:next_token] = start_key if @start
        opts[:scan_index_forward] = @scan_index_forward
        opts
      end
      
      def scan_opts
        opts = {}
        opts[:limit] = @eval_limit if @eval_limit
        opts[:next_token] = start_key if @start
        opts[:batch_size] = @batch_size if @batch_size
        opts
      end
    end

  end

end
