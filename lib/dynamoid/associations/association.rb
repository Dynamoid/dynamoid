# encoding: utf-8
module Dynamoid #:nodoc:

  # The base association module.
  module Associations
    module Association
      attr_accessor :name, :options, :source, :query
      include Enumerable

      delegate :first, :last, :empty?, :size, :to => :records

      def initialize(source, name, options)
        @name = name
        @options = options
        @source = source
        @query = {}
      end
      
      alias :nil? :empty?
      alias :count :size
      
      def records
        results = Array(target_class.find(source_ids.to_a))

        if query.empty?
          results
        else
          results_with_query(results)
        end
      end
      alias :all :records
      
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
        self << target_class.create(attributes)
      end

      def create!(attributes = {})
        self << target_class.create!(attributes)
      end
      
      def where(args)
        args.each {|k, v| query[k] = v}
        self
      end
      
      def each(&block)
        records.each(&block)
      end

      def destroy_all
        records.each(&:destroy)
      end

      def delete_all
        records.each(&:delete)
      end
      
      private
      
      def results_with_query(results)
        results.find_all do |result|
          query.all? do |attribute, value|
            result.send(attribute) == value
          end
        end
      end

      def target_class_name
        options[:class_name] || name.to_s.singularize.camelize
      end

      def target_class
        options[:class] || target_class_name.constantize
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
