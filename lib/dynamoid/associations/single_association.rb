# encoding: utf-8
module Dynamoid #:nodoc:

  module Associations
    module SingleAssociation

      delegate :class, :to => :target

      def setter(object)
        delete
        source.update_attribute(source_attribute, Set[object.id])
        self.send(:associate_target, object) if target_association
        object
      end

      def delete
        source.update_attribute(source_attribute, nil)
        self.send(:disassociate_target, target) if target && target_association
        target
      end

      def create!(attributes = {})
        setter(target_class.create!(attributes))
      end

      def create(attributes = {})
        setter(target_class.create!(attributes))
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

      private

      # Find the target of the has_one association.
      #
      # @return [Dynamoid::Document] the found target (or nil if nothing)
      #
      # @since 0.2.0
      def target
        return if source_ids.empty?
        target_class.find(source_ids.first)
      end
    end
  end
end
