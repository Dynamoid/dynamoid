# encoding: utf-8
module Dynamoid #:nodoc:
  module Criteria

    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it either on an index
    # or by a full table scan.
    class Chain
      attr_accessor :query, :source, :index, :values
      include Enumerable
      
      # Create a new criteria chain.
      #
      # @param [Class] source the class upon which the ultimate query will be performed.
      def initialize(source)
        @query = {}
        @source = source
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
        args.each {|k, v| query[k] = v}
        self
      end
      
      # Returns all the records matching the criteria.
      #
      # @since 0.2.0
      def all
        records
      end

      # Returns the first record matching the criteria.
      #
      # @since 0.2.0      
      def first
        records.first
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
      # @return [Array] an array of the found records.
      #
      # @since 0.2.0
      def records
        return records_with_index if index
        records_without_index
      end

      # If the query matches an index on the associated class, then this method will retrieve results from the index table.
      #
      # @return [Array] an array of the found records.
      #
      # @since 0.2.0      
      def records_with_index
        ids = if index.range_key?
          Dynamoid::Adapter.query(index.table_name, index_query).collect{|r| r[:ids]}.inject(Set.new) {|set, result| set + result}
        else
          results = Dynamoid::Adapter.read(index.table_name, index_query[:hash_value])
          if results
            results[:ids]
          else
            []
          end
        end
        if ids.nil? || ids.empty?
          []
        else
          Array(source.find(ids.to_a))
        end
      end
      
      # If the query does not match an index, we'll manually scan the associated table to manually find results.
      #
      # @return [Array] an array of the found records.
      #
      # @since 0.2.0      
      def records_without_index
        if Dynamoid::Config.warn_on_scan
          Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
          Dynamoid.logger.warn "You can index this query by adding this to #{source.to_s.downcase}.rb: index [#{source.attributes.sort.collect{|attr| ":#{attr}"}.join(', ')}]"
        end
        Dynamoid::Adapter.scan(source.table_name, query).collect {|hash| source.new(hash).tap { |r| r.new_record = false } }
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
              if query[key].is_a?(Range)
                hash[:range_value] = query[key]
              else
                val = query[key].to_f
                case key.split('.').last
                when 'gt'
                  hash[:range_greater_than] = val
                when 'lt'
                  hash[:range_less_than] = val
                when 'gte'
                  hash[:range_gte] = val
                when 'lte'
                  hash[:range_lte] = val
                end
              end
            else
              raise Dynamoid::Errors::MissingRangeKey, 'This index requires a range key'
            end
          end
        end
      end

      # Return an index that fulfills all the attributes the criteria is querying, or nil if none is found.
      #
      # @since 0.2.0            
      def index
        index = source.find_index(query.keys.collect{|k| k.to_s.split('.').first})
        return nil if index.blank?
        index
      end
    end
    
  end
  
end
