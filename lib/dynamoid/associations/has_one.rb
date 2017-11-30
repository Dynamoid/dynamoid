# encoding: utf-8
module Dynamoid #:nodoc:

  # The HasOne association.
  module Associations
    class HasOne
      include Association
      include SingleAssociation

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
    end
  end

end
