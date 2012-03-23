# encoding: utf-8
module Dynamoid #:nodoc:

  # The has and belongs to many association.
  module Associations
    class HasAndBelongsToMany
      include Dynamoid::Associations::Association
      
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
      
      # Find the target association, always another :has_and_belongs_to_many association. Uses either options[:inverse_of] or the source class name 
      # and default parsing to return the most likely name for the target association.
      #
      # @since 0.2.0
      def target_association
        key_name = options[:inverse_of] || source.class.to_s.pluralize.underscore.to_sym
        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :has_and_belongs_to_many
        key_name
      end
            
      # Associate a source object to this association.
      #
      # @since 0.2.0      
      def associate_target(object)
        ids = object.send(target_attribute) || Set.new
        object.update_attribute(target_attribute, ids.merge(Array(source.id)))
      end
      
      # Disassociate a source object from this association.
      #
      # @since 0.2.0
      def disassociate_target(object)
        ids = object.send(target_attribute) || Set.new
        object.update_attribute(target_attribute, ids - Array(source.id))
      end
    end
  end
  
end
