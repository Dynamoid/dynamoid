# encoding: utf-8
module Dynamoid #:nodoc:

  # The BelongsTo association.
  module Associations
    class BelongsTo
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
        has_many_key_name = options[:inverse_of] || source.class.to_s.pluralize.downcase.to_sym
        has_one_key_name = options[:inverse_of] || source.class.to_s.downcase.to_sym
        if !target_class.associations[has_many_key_name].nil?
          return has_many_key_name if target_class.associations[has_many_key_name][:type] == :has_many
        end

        if !target_class.associations[has_one_key_name].nil?
          return has_one_key_name if target_class.associations[has_one_key_name][:type] == :has_one
        end
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
