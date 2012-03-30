# encoding: utf-8
module Dynamoid #:nodoc:

  module Associations
    module ManyAssociation

      attr_accessor :query

      def initialize(*args)
        @query = {}
        super
      end

      include Enumerable
      # Delegate methods to the records the association represents.
      delegate :first, :last, :empty?, :size, :class, :to => :records

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

      # Alias convenience methods for the associations.
      alias :all :records
      alias :count :size
      alias :nil? :empty?

      # Delegate include? to the records.
      def include?(object)
        records.include?(object)
      end

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
        Array(object).each {|o| self.send(:disassociate_target, o)} if target_association
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
        Array(object).each {|o| self.send(:associate_target, o)} if target_association
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

      # Is this array equal to the association's records?
      #
      # @return [Boolean] true/false
      #
      # @since 0.2.0
      def ==(other)
        records == Array(other)
      end

      # Delegate methods we don't find directly to the records array.
      #
      # @since 0.2.0
      def method_missing(method, *args)
        if records.respond_to?(method)
          records.send(method, *args)
        else
          super
        end
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

    end
  end
end
