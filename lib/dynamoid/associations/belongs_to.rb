# frozen_string_literal: true

module Dynamoid
  # The belongs_to association. For belongs_to, we reference only a single target instead of multiple records; that target is the
  # object to which the association object is associated.
  module Associations
    # @private
    class BelongsTo
      include SingleAssociation

      def declaration_field_name
        options[:foreign_key] || "#{name}_ids"
      end

      def declaration_field_type
        if options[:foreign_key]
          target_class.attributes[target_class.hash_key][:type]
        else
          :set
        end
      end

      # Override default implementation
      # to handle case when we store id as scalar value, not as collection
      def associate(hash_key)
        target.send(target_association).disassociate(source.hash_key) if target && target_association

        if options[:foreign_key]
          source.update_attribute(source_attribute, hash_key)
        else
          source.update_attribute(source_attribute, Set[hash_key])
        end
      end

      private

      # Find the target association, either has_many or has_one. Uses either options[:inverse_of] or the source class name and default parsing to
      # return the most likely name for the target association.
      #
      # @since 0.2.0
      def target_association
        name = options[:inverse_of] || source.class.to_s.underscore.pluralize.to_sym
        if target_class.associations.dig(name, :type) == :has_many
          return name
        end

        name = options[:inverse_of] || source.class.to_s.underscore.to_sym
        if target_class.associations.dig(name, :type) == :has_one
          return name # rubocop:disable Style/RedundantReturn
        end
      end
    end
  end
end
