# encoding: utf-8
module Dynamoid #:nodoc:

  # The base association module.
  module Associations
    module Association
      attr_accessor :name, :options, :source

      def initialize(source, name, options)
        @name = name
        @options = options
        @source = source
      end
      
      def empty?
        records.empty?
      end
      
      def size
        records.count
      end
      
      def include?(object)
        records.include?(object)
      end
      
      def delete(object)
        source.update_attribute(source_attribute, source_ids - Array(object).collect(&:id))
        Array(object).collect{|o| self.send(:disassociate_target, o)}
        object
      end
      
      def <<(object)
        source.update_attribute(source_attribute, source_ids.merge(Array(object).collect(&:id)))
        Array(object).collect{|o| self.send(:associate_target, o)}
        object
      end
      
      def create(attributes = {})
        object = target_class.create(attributes)
        self << object
      end
      
      private
      
      def records
        results = target_class.find(source_ids.to_a)
        results.nil? ? [] : Array(results)
      end
      
      def target_class
        name.to_s.singularize.capitalize.constantize
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