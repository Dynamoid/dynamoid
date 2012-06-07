# encoding: utf-8
module Dynamoid #:nodoc:
  module Indexes

    # The class contains all the information an index contains, including its keys and which attributes it covers.
    class Index
      attr_accessor :source, :name, :hash_keys, :range_keys
      alias_method :range_key?, :range_keys
      
      # Create a new index. Pass either :range => true or :range => :column_name to create a ranged index on that column.
      #
      # @param [Class] source the source class for the index
      # @param [Symbol] name the name of the index
      #
      # @since 0.2.0      
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
      
      # Sort objects into alphabetical strings, used for composing index names correctly (since we always assume they're alphabetical).
      #
      # @example find all users by first and last name
      #   sort([:gamma, :alpha, :beta, :omega]) # => [:alpha, :beta, :gamma, :omega]
      #
      # @since 0.2.0         
      def sort(objs)
        Array(objs).flatten.compact.uniq.collect(&:to_s).sort.collect(&:to_sym)
      end

      # Return the array of keys this index uses for its table.
      #
      # @since 0.2.0      
      def keys
        [Array(hash_keys) + Array(range_keys)].flatten.uniq
      end
      
      # Return the table name for this index.
      #
      # @since 0.2.0
      def table_name
        "#{Dynamoid::Config.namespace}_index_" + source.table_name.sub("#{Dynamoid::Config.namespace}_", '').singularize + "_#{name.collect(&:to_s).collect(&:pluralize).join('_and_')}"
      end

      # Given either an object or a list of attributes, generate a hash key and a range key for the index. Optionally pass in 
      # true to changed_attributes for a list of all the object's dirty attributes in convenient index form (for deleting stale 
      # information from the indexes).
      #
      # @param [Object] attrs either an object that responds to :attributes, or a hash of attributes
      #
      # @return [Hash] a hash with the keys :hash_value and :range_value
      #
      # @since 0.2.0
      def values(attrs, changed_attributes = false)
        if changed_attributes
          hash = {}
          attrs.changes.each {|k, v| hash[k.to_sym] = (v.first || v.last)}
          attrs = hash
        end
        attrs = attrs.send(:attributes) if attrs.respond_to?(:attributes)
        {}.tap do |hash|
          hash[:hash_value] = hash_keys.collect{|key| attrs[key]}.join('.')
          hash[:range_value] = range_keys.inject(0.0) {|sum, key| sum + attrs[key].to_f} if self.range_key?
        end
      end
      
      # Save an object to this index, merging it with existing ids if there's already something present at this index location.
      # First, though, delete this object from its old indexes (so the object isn't listed in an erroneous index).
      #
      # @since 0.2.0
      def save(obj)
        self.delete(obj, true)
        values = values(obj)
        return true if values[:hash_value].blank? || (!values[:range_value].nil? && values[:range_value].blank?)
        existing = Dynamoid::Adapter.read(self.table_name, values[:hash_value], { :range_key => values[:range_value] })
        ids = ((existing and existing[:ids]) or Set.new)
        Dynamoid::Adapter.write(self.table_name, {:id => values[:hash_value], :ids => ids.merge([obj.id]), :range => values[:range_value]})
      end

      # Delete an object from this index, preserving existing ids if there are any, and failing gracefully if for some reason the 
      # index doesn't already have this object in it.
      #
      # @since 0.2.0      
      def delete(obj, changed_attributes = false)
        values = values(obj, changed_attributes)
        return true if values[:hash_value].blank? || (!values[:range_value].nil? && values[:range_value].blank?)
        existing = Dynamoid::Adapter.read(self.table_name, values[:hash_value], { :range_key => values[:range_value]})
        return true unless existing && existing[:ids] && existing[:ids].include?(obj.id)
        Dynamoid::Adapter.write(self.table_name, {:id => values[:hash_value], :ids => (existing[:ids] - Set[obj.id]), :range => values[:range_value]})
      end
      
    end
  end
end
