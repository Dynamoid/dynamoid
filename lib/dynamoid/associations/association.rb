# encoding: utf-8
module Dynamoid #:nodoc:

  # The base association module.
  module Associations
    module Association
      attr_accessor :name, :options, :source, :query
      include Enumerable

      def initialize(source, name, options)
        @name = name
        @options = options
        @source = source
        @query = {}
      end
      
      def records
        results = target_class.find(source_ids.to_a)
        results = results.nil? ? [] : Array(results)
        return results if query.empty?
        results_with_query(results)
      end
      alias :all :records
      
      def empty?
        records.empty?
      end
      alias :nil? :empty?
      
      def size
        records.count
      end
      alias :count :size
      
      def include?(object)
        records.include?(object)
      end
      
      def delete(object)
        source.update_attribute(source_attribute, source_ids - Array(object).collect(&:id))
        Array(object).collect{|o| self.send(:disassociate_target, o)} if target_association
        object
      end
      
      def <<(object)
        source.update_attribute(source_attribute, source_ids.merge(Array(object).collect(&:id)))
        Array(object).collect{|o| self.send(:associate_target, o)} if target_association
        object
      end
      
      def setter(object)
        source.update_attribute(source_attribute, Array(object).collect(&:id))
        Array(object).collect{|o| self.send(:associate_target, o)} if target_association
        object
      end
      
      def create(attributes = {})
        object = target_class.create(attributes)
        self << object
      end
      
      def where(args)
        args.each {|k, v| query[k] = v}
        self
      end
      
      def each(&block)
        records.each(&block)
      end
      
      private
      
      def results_with_query(results)
        results.find_all do |result|
          query.all? do |attribute, value|
            result.send(attribute) == value
          end
        end
      end
      
      def target_class
        name.to_s.singularize.camelize.constantize
      end
      
      def target_attribute
        "#{target_association}_ids".to_sym if target_association
      end
      
      def target_ids
        target.send(target_attribute) || Set.new
      end
      
      def source_class
        source.class
      end
      
      def source_attribute
        "#{name}_ids".to_sym
      end
      
      def source_ids
        source.send(source_attribute) || Set.new
      end

    end
  end
  
end
