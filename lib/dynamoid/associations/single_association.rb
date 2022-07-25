# frozen_string_literal: true

module Dynamoid
  module Associations
    module SingleAssociation
      include Association

      delegate :class, to: :target

      # @private
      def setter(object)
        if object.nil?
          delete
          return
        end

        associate(object.hash_key)
        self.target = object
        if target_association
          object.send(target_association).associate(source.hash_key)
        end
        object
      end

      # Delete a model from the association.
      #
      #   post.logo.delete # => nil
      #
      # Saves both models immediately - a source model and a target one so any
      # unsaved changes will be saved. Doesn't delete an associated model from
      # DynamoDB.
      def delete
        disassociate_source
        disassociate
        target
      end

      # Create a new instance of the target class, persist it and associate.
      #
      #   post.logo.create!(hight: 50, width: 90)
      #
      # If the creation fails an exception will be raised.
      #
      # @param attributes [Hash] attributes of a model to create
      # @return [Dynamoid::Document] created model
      def create!(attributes = {})
        setter(target_class.create!(attributes))
      end

      # Create a new instance of the target class, persist it and associate.
      #
      #   post.logo.create(hight: 50, width: 90)
      #
      # @param attributes [Hash] attributes of a model to create
      # @return [Dynamoid::Document] created model
      def create(attributes = {})
        setter(target_class.create(attributes))
      end

      # Is this object equal to the association's target?
      #
      # @return [Boolean] true/false
      #
      # @since 0.2.0
      def ==(other)
        target == other
      end

      # Delegate methods we don't find directly to the target.
      #
      # @private
      # @since 0.2.0
      def method_missing(method, *args, **kwargs)
        if target.respond_to?(method)
          target.send(method, *args, **kwargs)
        else
          super
        end
      end

      # @private
      def nil?
        target.nil?
      end

      # @private
      def empty?
        # This is needed to that ActiveSupport's #blank? and #present?
        # methods work as expected for SingleAssociations.
        target.nil?
      end

      # @private
      def associate(hash_key)
        disassociate_source
        source.update_attribute(source_attribute, Set[hash_key])
      end

      # @private
      def disassociate(_hash_key = nil)
        source.update_attribute(source_attribute, nil)
      end

      private

      # Find the target of the has_one association.
      #
      # @return [Dynamoid::Document] the found target (or nil if nothing)
      #
      # @since 0.2.0
      def find_target
        return if source_ids.empty?

        target_class.find(source_ids.first, raise_error: false)
      end

      def target=(object)
        @target = object
        @loaded = true
      end
    end
  end
end
