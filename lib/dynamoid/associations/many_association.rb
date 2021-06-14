# frozen_string_literal: true

module Dynamoid
  module Associations
    module ManyAssociation
      include Association

      attr_accessor :query

      def initialize(*args)
        @query = {}
        super
      end

      include Enumerable

      # @private
      # Delegate methods to the records the association represents.
      delegate :first, :last, :empty?, :size, :class, to: :records

      # The records associated to the source.
      #
      # @return the association records; depending on which association this is, either a single instance or an array
      #
      # @private
      # @since 0.2.0
      def find_target
        return [] if source_ids.empty?

        Array(target_class.find(source_ids.to_a, raise_error: false))
      end

      # @private
      def records
        if query.empty?
          target
        else
          results_with_query(target)
        end
      end

      # Alias convenience methods for the associations.
      alias all records
      alias count size
      alias nil? empty?

      # Delegate include? to the records.
      def include?(object)
        records.include?(object)
      end

      # Delete an object or array of objects from the association.
      #
      #   tag.posts.delete(post)
      #   tag.posts.delete([post1, post2, post3])
      #
      # This removes their records from the association field on the source,
      # and attempts to remove the source from the target association if it is
      # detected to exist.
      #
      # It saves both models immediately - the source model and the target one
      # so any not saved changes will be saved as well.
      #
      # @param object [Dynamoid::Document|Array] model (or array of models) to remove from the association
      # @return [Dynamoid::Document|Array] the deleted model
      # @since 0.2.0
      def delete(object)
        disassociate(Array(object).collect(&:hash_key))
        if target_association
          Array(object).each { |obj| obj.send(target_association).disassociate(source.hash_key) }
        end
        object
      end

      # Add an object or array of objects to an association.
      #
      #   tag.posts << post
      #   tag.posts << [post1, post2, post3]
      #
      # This preserves the current records in the association (if any) and adds
      # the object to the target association if it is detected to exist.
      #
      # It saves both models immediately - the source model and the target one
      # so any not saved changes will be saved as well.
      #
      # @param object [Dynamoid::Document|Array] model (or array of models) to add to the association
      # @return [Dynamoid::Document] the added model
      # @since 0.2.0
      def <<(object)
        associate(Array(object).collect(&:hash_key))

        if target_association
          Array(object).each { |obj| obj.send(target_association).associate(source.hash_key) }
        end

        object
      end

      # Replace an association with object or array of objects. This removes all of the existing associated records and replaces them with
      # the passed object(s), and associates the target association if it is detected to exist.
      #
      # @param [Dynamoid::Document] object the object (or array of objects) to add to the association
      #
      # @return [Dynamoid::Document|Array] the added object
      #
      # @private
      # @since 0.2.0
      def setter(object)
        target.each { |o| delete(o) }
        self << object
        object
      end

      # Create a new instance of the target class, persist it and add directly
      # to the association.
      #
      #   tag.posts.create!(title: 'foo')
      #
      # Several models can be created at once when an array of attributes
      # specified:
      #
      #   tag.posts.create!([{ title: 'foo' }, {title: 'bar'} ])
      #
      # If the creation fails an exception will be raised.
      #
      # @param attributes [Hash] attribute values for the new object
      # @return [Dynamoid::Document|Array] the newly-created object
      # @since 0.2.0
      def create!(attributes = {})
        self << target_class.create!(attributes)
      end

      # Create a new instance of the target class, persist it and add directly
      # to the association.
      #
      #   tag.posts.create(title: 'foo')
      #
      # Several models can be created at once when an array of attributes
      # specified:
      #
      #   tag.posts.create([{ title: 'foo' }, {title: 'bar'} ])
      #
      # @param attributes [Hash] attribute values for the new object
      # @return [Dynamoid::Document|Array] the newly-created object
      # @since 0.2.0
      def create(attributes = {})
        self << target_class.create(attributes)
      end

      # Create a new instance of the target class and add it directly to the association. If the create fails an exception will be raised.
      #
      # @return [Dynamoid::Document] the newly-created object
      #
      # @private
      # @since 0.2.0
      def each(&block)
        records.each(&block)
      end

      # Destroys all members of the association and removes them from the
      # association.
      #
      #   tag.posts.destroy_all
      #
      # @since 0.2.0
      def destroy_all
        objs = target
        source.update_attribute(source_attribute, nil)
        objs.each(&:destroy)
      end

      # Deletes all members of the association and removes them from the
      # association.
      #
      #   tag.posts.delete_all
      #
      # @since 0.2.0
      def delete_all
        objs = target
        source.write_attribute(source_attribute, nil)
        source.save(skip_callbacks: true)
        objs.each(&:delete)
      end

      # Naive association filtering.
      #
      #   tag.posts.where(title: 'foo')
      #
      # It loads lazily all the associated models and checks provided
      # conditions. That's why only equality conditions can be specified.
      #
      # @param args [Hash] A hash of attributes; each must match every returned object's attribute exactly.
      # @return [Dynamoid::Association] the association this method was called on (for chaining purposes)
      # @since 0.2.0
      def where(args)
        filtered = clone
        filtered.query = query.clone
        args.each { |k, v| filtered.query[k] = v }
        filtered
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
      # @private
      # @since 0.2.0
      def method_missing(method, *args)
        if records.respond_to?(method)
          records.send(method, *args)
        else
          super
        end
      end

      # @private
      def associate(hash_key)
        source.update_attribute(source_attribute, source_ids.merge(Array(hash_key)))
      end

      # @private
      def disassociate(hash_key)
        source.update_attribute(source_attribute, source_ids - Array(hash_key))
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
