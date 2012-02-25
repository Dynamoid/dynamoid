# encoding: utf-8
module Dynamoid #:nodoc:

  # The BelongsTo association.
  module Associations
    class BelongsTo
      include Dynamoid::Associations::Association
      
      def ==(other)
        target == other
      end
      
      def nil?
        records.empty?
      end
      alias :nil? :empty?
      
      private
      
      def target
        records.first
      end
      
      def target_association
        key_name = source.class.to_s.pluralize.downcase.to_sym
        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :has_many
        key_name
      end
      
      def associate_target(object)
        object.update_attribute(target_attribute, target_ids.merge(Array(source.id)))
      end
      
      def disassociate_target(object)
        source.update_attribute(source_attribute, target_ids - Array(source.id))
      end
    end
  end
  
end