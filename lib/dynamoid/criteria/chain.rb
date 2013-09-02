# encoding: utf-8
module Dynamoid #:nodoc:
  module Criteria

    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it either on an index
    # or by a full table scan.
    class Chain
      attr_accessor :query, :source, :index, :values, :limit, :start, :consistent_read
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
      def all(opts = {})
        batch opts[:batch_size] if opts.has_key? :batch_size
        records
      end
      
      # Destroys all the records matching the criteria.
      #
      def destroy_all
        ids = []
        
        if range?
          ranges = []
          Dynamoid::Adapter.query(source.table_name, range_query).collect do |hash| 
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym]
          end
          
          Dynamoid::Adapter.delete(source.table_name, ids,{:range_key => ranges})
        elsif index
          #TODO: test this throughly and find a way to delete all index table records for one source record
          if index.range_key?
            results = Dynamoid::Adapter.query(index.table_name, index_query.merge(consistent_opts))
          else
            results = Dynamoid::Adapter.read(index.table_name, index_query[:hash_value], consistent_opts)
          end
          
          results.collect do |hash| 
            ids << hash[source.hash_key.to_sym]
            index_ranges << hash[source.range_key.to_sym]
          end
        
          unless ids.nil? || ids.empty?
            ids = ids.to_a
  
            if @start
              ids = ids.drop_while { |id| id != @start.hash_key }.drop(1)
              index_ranges = index_ranges.drop_while { |range| range != @start.hash_key }.drop(1) unless index_ranges.nil?
            end
  
            if @limit           
              ids = ids.take(@limit) 
              index_ranges = index_ranges.take(@limit)
            end
            
            Dynamoid::Adapter.delete(source.table_name, ids)
            
            if index.range_key?
              Dynamoid::Adapter.delete(index.table_name, ids,{:range_key => index_ranges})
            else
              Dynamoid::Adapter.delete(index.table_name, ids)
            end
            
          end
        else
          Dynamoid::Adapter.scan(source.table_name, query, scan_opts).collect do |hash| 
            ids << hash[source.hash_key.to_sym]
          end
          
          Dynamoid::Adapter.delete(source.table_name, ids)
        end   
      end

      # Returns the first record matching the criteria.
      #
      # @since 0.2.0
      def first
        limit(1).first
      end

      def limit(limit)
        @limit = limit
        records
      end

      def batch(batch_size)
        raise 'Cannot batch calls when using partitioning' if Dynamoid::Config.partitioning?
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
        results = if range?
          records_with_range
        elsif index
          records_with_index
        else
          records_without_index
        end
        @batch_size ? results : Array(results)
      end

      # If the query matches an index on the associated class, then this method will retrieve results from the index table.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records_with_index
        ids = ids_from_index
        if ids.nil? || ids.empty?
          [].to_enum
        else
          ids = ids.to_a

          if @start
            ids = ids.drop_while { |id| id != @start.hash_key }.drop(1)
          end

          ids = ids.take(@limit) if @limit
          source.find(ids, consistent_opts)
        end
      end

      # Returns the Set of IDs from the index table.
      #
      # @return [Set] a Set containing the IDs from the index.
      def ids_from_index
        if index.range_key?
          Dynamoid::Adapter.query(index.table_name, index_query.merge(consistent_opts)).inject(Set.new) do |all, record|
            all + Set.new(record[:ids])
          end
        else
          results = Dynamoid::Adapter.read(index.table_name, index_query[:hash_value], consistent_opts)
          results ? results[:ids] : []
        end
      end

      def records_with_range
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
      def records_without_index
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

      # Format the provided query so that it can be used to query results from DynamoDB.
      #
      # @return [Hash] a hash with keys of :hash_value and :range_value
      #
      # @since 0.2.0
      def index_query
        values = index.values(query)
        {}.tap do |hash|
          hash[:hash_value] = values[:hash_value]
          if index.range_key?
            key = query.keys.find{|k| k.to_s.include?('.')}
            if key
              hash.merge!(range_hash(key))
            else
              raise Dynamoid::Errors::MissingRangeKey, 'This index requires a range key'
            end
          end
        end
      end

      def range_hash(key)
        val = query[key]

        return { :range_value => query[key] } if query[key].is_a?(Range)

        case key.split('.').last
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

      # Return an index that fulfills all the attributes the criteria is querying, or nil if none is found.
      #
      # @since 0.2.0
      def index
        index = source.find_index(query_keys)
        return nil if index.blank?
        index
      end

      def query_keys
        query.keys.collect{|k| k.to_s.split('.').first}
      end

      # Use range query only when [hash_key] or [hash_key, range_key] is specified in query keys.
      def range?
        return false unless query_keys.include?(source.hash_key.to_s) or query_keys.include?(source.range_key.to_s)
        query_keys == [source.hash_key.to_s] || (query_keys.to_set == [source.hash_key.to_s, source.range_key.to_s].to_set)
      end

      def start_key
 	      hash_key_type = @start.class.attributes[@start.class.hash_key][:type] == :string ? 'S' : 'N'
        key = { :hash_key_element => { hash_key_type => @start.hash_key.to_s } }
        if range_key = @start.class.range_key
          range_key_type = @start.class.attributes[range_key][:type] == :string ? 'S' : 'N'
          key.merge!({:range_key_element => { range_key_type => @start.send(range_key).to_s } })
        end
        key
      end

      def query_opts
        opts = {}
        opts[:limit] = @limit if @limit
        opts[:next_token] = start_key if @start
        opts[:scan_index_forward] = @scan_index_forward
        opts
      end
      
      def scan_opts
        opts = {}
        opts[:limit] = @limit if @limit
        opts[:next_token] = start_key if @start
        opts[:batch_size] = @batch_size if @batch_size
        opts
      end
    end

  end

end
