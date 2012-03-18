# encoding: utf-8
module Dynamoid #:nodoc:
  module Criteria

    # The class object that gets passed around indicating state of a building query.
    # Also provides query execution.
    class Chain
      attr_accessor :query, :source, :index, :values
      include Enumerable
      
      def initialize(source)
        @query = {}
        @source = source
      end
      
      def where(args)
        args.each {|k, v| query[k] = v}
        self
      end
      
      def all
        records
      end
      
      def first
        records.first
      end
      
      def each(&block)
        records.each(&block)
      end
      
      private
      
      def records
        return records_with_index if index
        records_without_index
      end
      
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
      
      def records_without_index
        if Dynamoid::Config.warn_on_scan
          Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
          Dynamoid.logger.warn "You can index this query by adding this to #{source.to_s.downcase}.rb: index [#{source.attributes.sort.collect{|attr| ":#{attr}"}.join(', ')}]"
        end
        Dynamoid::Adapter.scan(source.table_name, query).collect {|hash| source.new(hash).tap { |r| r.new_record = false } }
      end
      
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
      
      def index
        index = source.find_index(query.keys.collect{|k| k.to_s.split('.').first})
        return nil if index.blank?
        index
      end
    end
    
  end
  
end
