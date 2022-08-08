# frozen_string_literal: true

module Dynamoid
  # The has_many association.
  module Associations
    # @private
    class HasMany
      include ManyAssociation

      private

      # Find the target association, always a :belongs_to association. Uses either options[:inverse_of] or the source class name
      # and default parsing to return the most likely name for the target association.
      #
      # @since 0.2.0
      def target_association
        key_name = options[:inverse_of] || source.class.to_s.singularize.underscore.to_sym

        if target_class.module_parent != Object && (target_class.module_parent == source.class.module_parent)
          key_name = source.class.to_s.demodulize.singularize.underscore.to_sym
        end

        guess = target_class.associations[key_name]
        return nil if guess.nil? || guess[:type] != :belongs_to

        key_name
      end
    end
  end
end
