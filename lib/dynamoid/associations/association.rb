# encoding: utf-8
module Dynamoid #:nodoc:

  # The base association module which all associations include. Every association has two very important components: the source and 
  # the target. The source is the object which is calling the association information. It always has the target_ids inside of an attribute on itself.
  # The target is the object which is referencing by this association.
  module Associations
    module Association
      attr_accessor :name, :options, :source, :query
      include Enumerable

      # Delegate methods to the records the association represents.
      delegate :first, :last, :empty?, :size, :to => :records

      # Create a new association.
      # 
      # @param [Class] source the source record of the association; that is, the record that you already have
      # @param [Symbol] name the name of the association
      # @param [Hash] options optional parameters for the association
      # @option options [Class] :class the target class of the association; that is, the class to which the association objects belong
      # @option options [Symbol] :class_name the name of the target class of the association; only this or Class is necessary
      # @option options [Symbol] :inverse_of the name of the association on the target class
      #
      # @return [Dynamoid::Association] the actual association instance itself
      #
      # @since 0.2.0
      def initialize(source, name, options)
        @name = name
        @options = options
        @source = source
        @query = {}
      end
      
      # Alias convenience methods for the associations.
      alias :nil? :empty?
      alias :count :size
      
      # The records associated to the source.
      # 
      # @return the association records; depending on which association this is, either a single instance or an array
      #
      # @since 0.2.0
      def records
        results = Array(target_class.find(source_ids.to_a))

        if query.empty?
          results
        else
          results_with_query(results)
        end
      end
      alias :all :records
      
      # Delegate include? to the records.
      def include?(object)
        records.include?(object)
      end
      
      # @todo Improve the two methods below to not have quite so much duplicated code.
      
      # Deletes an object or array of objects from the association. This removes their records from the association field on the source, 
      # and attempts to remove the source from the target association if it is detected to exist.
      # 
      # @param [Dynamoid::Document] object the object (or array of objects) to remove from the association
      #
      # @return [Dynamoid::Document] the deleted object
      #
      # @since 0.2.0
      def delete(object)
        source.update_attribute(source_attribute, source_ids - Array(object).collect(&:id))
        Array(object).collect{|o| self.send(:disassociate_target, o)} if target_association
        object
      end

      # Add an object or array of objects to an association. This preserves the current records in the association (if any)
      # and adds the object to the target association if it is detected to exist.
      # 
      # @param [Dynamoid::Document] object the object (or array of objects) to add to the association
      #
      # @return [Dynamoid::Document] the added object
      #
      # @since 0.2.0      
      def <<(object)
        source.update_attribute(source_attribute, source_ids.merge(Array(object).collect(&:id)))
        Array(object).collect{|o| self.send(:associate_target, o)} if target_association
        object
      end

      # Replace an association with object or array of objects. This removes all of the existing associated records and replaces them with
      # the passed object(s), and associates the target association if it is detected to exist.
      # 
      # @param [Dynamoid::Document] object the object (or array of objects) to add to the association
      #
      # @return [Dynamoid::Document] the added object
      #
      # @since 0.2.0            
      def setter(object)
        records.each {|o| delete(o)}
        self << (object)
        object
      end
      
      # Create a new instance of the target class and add it directly to the association.
      # 
      # @param [Hash] attribute hash for the new object
      #
      # @return [Dynamoid::Document] the newly-created object
      #
      # @since 0.2.0            
      def create(attributes = {})
        self << target_class.create(attributes)
      end
      
      # Create a new instance of the target class and add it directly to the association. If the create fails an exception will be raised.
      # 
      # @param [Hash] attribute hash for the new object
      #
      # @return [Dynamoid::Document] the newly-created object
      #
      # @since 0.2.0            
      def create!(attributes = {})
        self << target_class.create!(attributes)
      end
      
      
      # Naive association filtering.
      # 
      # @param [Hash] A hash of attributes; each must match every returned object's attribute exactly.
      #
      # @return [Dynamoid::Association] the association this method was called on (for chaining purposes)
      #
      # @since 0.2.0            
      def where(args)
        args.each {|k, v| query[k] = v}
        self
      end
      
      # Create a new instance of the target class and add it directly to the association. If the create fails an exception will be raised.
      # 
      # @param [Hash] attribute hash for the new object
      #
      # @return [Dynamoid::Document] the newly-created object
      #
      # @since 0.2.0            
      def each(&block)
        records.each(&block)
      end

      # Destroys all members of the association and removes them from the association.
      # 
      # @since 0.2.0
      def destroy_all
        objs = records
        source.update_attribute(source_attribute, nil)
        objs.each(&:destroy)
      end

      # Deletes all members of the association and removes them from the association.
      # 
      # @since 0.2.0
      def delete_all
        objs = records
        source.update_attribute(source_attribute, nil)
        objs.each(&:delete)
      end
      
      private
      
      # If a query exists, filter all existing results based on that query.
      #
      # @param [Array] results the raw results for the association
      #
      # @return [Array] the filtered results for the query
      # 
      # @since 0.2.0
      def results_with_query(results)
        results.find_all do |result|
          query.all? do |attribute, value|
            result.send(attribute) == value
          end
        end
      end

      # The target class name, either inferred through the association's name or specified in options.
      #
      # @since 0.2.0
      def target_class_name
        options[:class_name] || name.to_s.classify
      end

      # The target class, either inferred through the association's name or specified in options.
      #
      # @since 0.2.0
      def target_class
        options[:class] || target_class_name.constantize
      end
      
      # The target attribute: that is, the attribute on each object of the association that should reference the source.
      #
      # @since 0.2.0
      def target_attribute
        "#{target_association}_ids".to_sym if target_association
      end

      # The ids in the target association.
      #
      # @since 0.2.0      
      def target_ids
        target.send(target_attribute) || Set.new
      end

      # The ids in the target association.
      #
      # @since 0.2.0            
      def source_class
        source.class
      end
      
      # The source's association attribute: the name of the association with _ids afterwards, like "users_ids".
      #
      # @since 0.2.0
      def source_attribute
        "#{name}_ids".to_sym
      end
      
      # The ids in the source association.
      #
      # @since 0.2.0
      def source_ids
        source.send(source_attribute) || Set.new
      end

    end
  end
  
end
