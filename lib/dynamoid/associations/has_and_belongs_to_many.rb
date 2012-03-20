# encoding: utf-8
module Dynamoid #:nodoc:

  # The habtm association.
  module Associations
    class HasAndBelongsToMany
      include Dynamoid::Associations::Association
      
      def ==(other)
        records == Array(other)
      end
      
      private
      
      def target_association
        key_name = options[:inverse_of] || source.class.to_s.pluralize.underscore.to_sym
        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :has_and_belongs_to_many
        key_name
      end
            
      def associate_target(object)
        ids = object.send(target_attribute) || Set.new
        object.update_attribute(target_attribute, ids.merge(Array(source.id)))
      end
      
      def disassociate_target(object)
        ids = object.send(target_attribute) || Set.new
        object.update_attribute(target_attribute, ids - Array(source.id))
      end
    end
  end
  
end
