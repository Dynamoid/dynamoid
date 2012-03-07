# encoding: utf-8
module Dynamoid #:nodoc:

  # The HasOne association.
  module Associations
    class HasOne
      include Dynamoid::Associations::Association
      
      def ==(other)
        target == other
      end

      def method_missing(method, *args)
        if target.respond_to?(method)
          target.send(method, *args)
        else
          super
        end
      end
      
      private
      
      def target
        records.first
      end
      
      def target_association
        key_name = source.class.to_s.singularize.downcase.to_sym
        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :belongs_to
        key_name
      end
      
      def associate_target(object)
        object.update_attribute(target_attribute, source.id)
      end
      
      def disassociate_target(object)
        source.update_attribute(source_attribute, nil)
      end
    end
  end
  
end
