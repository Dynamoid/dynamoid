# frozen_string_literal: true

module Dynamoid #:nodoc:
  module Associations
    module SingleAssociation
      include Association

      delegate :class, to: :target

      def setter(object)
        if object.nil?
          delete
          return
        end

        associate(object.hash_key)
        self.target = object
        object.send(target_association).associate(source.hash_key) if target_association
        object
      end

      def delete
        target.send(target_association).disassociate(source.hash_key) if target && target_association
        disassociate
        target
      end

      def create!(attributes = {})
        setter(target_class.create!(attributes))
      end

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
      # @since 0.2.0
      def method_missing(method, *args)
        if target.respond_to?(method)
          target.send(method, *args)
        else
          super
        end
      end

      def nil?
        target.nil?
      end

      def empty?
        # This is needed to that ActiveSupport's #blank? and #present?
        # methods work as expected for SingleAssociations.
        target.nil?
      end

      def associate(hash_key)
        target.send(target_association).disassociate(source.hash_key) if target && target_association
        source.update_attribute(source_attribute, Set[hash_key])
      end

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
        target_class.find(source_ids.first)
      end

      def target=(object)
        @target = object
        @loaded = true
      end
    end
  end
end
