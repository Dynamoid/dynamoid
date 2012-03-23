# encoding: utf-8
module Dynamoid #:nodoc:
  module Indexes

    # The class contains all the information an index contains, including its keys and which attributes it covers.
    class Index
      attr_accessor :source, :name, :hash_keys, :range_keys
      alias_method :range_key?, :range_keys
      
      # Create a new index.
      def initialize(source, name, options = {})
        @source = source
        
        if options.delete(:range)
          @range_keys = sort(name)
        elsif options[:range_key]
          @range_keys = sort(options[:range_key])
        end
        @hash_keys = sort(name)
        @name = sort([hash_keys, range_keys])
        
        raise Dynamoid::Errors::InvalidField, 'A key specified for an index is not a field' unless keys.all?{|n| source.attributes.include?(n)}
      end
      
      def sort(objs)
        Array(objs).flatten.compact.uniq.collect(&:to_s).sort.collect(&:to_sym)
      end
      
      def keys
        [Array(hash_keys) + Array(range_keys)].flatten.uniq
      end
      
      def table_name
        "#{Dynamoid::Config.namespace}_index_#{source.to_s.downcase}_#{name.collect(&:to_s).collect(&:pluralize).join('_and_')}"
      end
      
      def values(attrs)
        attrs = attrs.send(:attributes) if attrs.respond_to?(:attributes)
        {}.tap do |hash|
          hash[:hash_value] = hash_keys.collect{|key| attrs[key]}.join('.')
          hash[:range_value] = range_keys.inject(0.0) {|sum, key| sum + attrs[key].to_f} if self.range_key?
        end
      end
      
      def save(obj)
        values = values(obj)
        return true if values[:hash_value].blank? || (!values[:range_value].nil? && values[:range_value].blank?)
        existing = Dynamoid::Adapter.read(self.table_name, values[:hash_value], values[:range_value])
        ids = ((existing and existing[:ids]) or Set.new)
        Dynamoid::Adapter.write(self.table_name, {:id => values[:hash_value], :ids => ids.merge([obj.id]), :range => values[:range_value]})
      end
      
      def delete(obj)
        values = values(obj)
        return true if values[:hash_value].blank? || (!values[:range_value].nil? && values[:range_value].blank?)
        existing = Dynamoid::Adapter.read(self.table_name, values[:hash_value], values[:range_value])
        return true unless existing && existing[:ids] && existing[:ids].include?(obj.id)
        Dynamoid::Adapter.write(self.table_name, {:id => values[:hash_value], :ids => (existing[:ids] - Set[obj.id]), :range => values[:range_value]})
      end
      
    end
  end
end
