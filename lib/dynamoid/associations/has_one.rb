# encoding: utf-8
module Dynamoid #:nodoc:

  # The HasOne association.
  module Associations
    class HasOne
      include Dynamoid::Associations::Association
      
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
      
      private
      
      # Find the target of the has_one association.
      #
      # @return [Dynamoid::Document] the found target (or nil if nothing)
      #
      # @since 0.2.0
      def target
        records.first
      end

      # Find the target association, always a :belongs_to association. Uses either options[:inverse_of] or the source class name 
      # and default parsing to return the most likely name for the target association.
      #
      # @since 0.2.0      
      def target_association
        key_name = options[:inverse_of] || source.class.to_s.singularize.underscore.to_sym
        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :belongs_to
        key_name
      end
      
      # Associate a source object to this association.
      #
      # @since 0.2.0      
      def associate_target(object)
        object.update_attribute(target_attribute, Set[source.id])
      end
      
      # Disassociate a source object from this association.
      #
      # @since 0.2.0      
      def disassociate_target(object)
        source.update_attribute(source_attribute, nil)
      end
    end
  end
  
end
