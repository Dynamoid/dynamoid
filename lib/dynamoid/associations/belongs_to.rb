# encoding: utf-8
module Dynamoid #:nodoc:

  # The belongs_to association. For belongs_to, we reference only a single target instead of multiple records; that target is the 
  # object to which the association object is associated.
  module Associations
    class BelongsTo
      include SingleAssociation

      private

      # Find the target association, either has_many or has_one. Uses either options[:inverse_of] or the source class name and default parsing to
      # return the most likely name for the target association.
      #
      # @since 0.2.0
      def target_association
        has_many_key_name = options[:inverse_of] || source.class.to_s.underscore.pluralize.to_sym
        has_one_key_name = options[:inverse_of] || source.class.to_s.underscore.to_sym
        if !target_class.associations[has_many_key_name].nil?
          return has_many_key_name if target_class.associations[has_many_key_name][:type] == :has_many
        end

        if !target_class.associations[has_one_key_name].nil?
          return has_one_key_name if target_class.associations[has_one_key_name][:type] == :has_one
        end
      end
      
      # Associate a source object to this association.
      #
      # @since 0.2.0
      def associate_target(object)
        object.update_attribute(target_attribute, target_ids.merge(Array(source.hash_key)))
      end

      # Disassociate a source object from this association.
      #
      # @since 0.2.0      
      def disassociate_target(object)
        source.update_attribute(source_attribute, target_ids - Array(source.hash_key))
      end
    end
  end
  
end
