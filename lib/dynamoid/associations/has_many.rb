# encoding: utf-8
module Dynamoid #:nodoc:

  # The has_many association.
  module Associations
    class HasMany
      include ManyAssociation

      private

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
        object.update_attribute(target_attribute, Set[source.hash_key])
      end
      
      # Disassociate a source object from this association.
      #
      # @since 0.2.0      
      def disassociate_target(object)
        object.update_attribute(target_attribute, nil)
      end
      
    end
  end
  
end
