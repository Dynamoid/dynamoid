# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    module UpdateValidations
      def self.validate_attributes_exist(model_class, attributes)
        model_attributes = model_class.attributes.keys

        attributes.each do |attr_name, _|
          unless model_attributes.include?(attr_name)
            raise Dynamoid::Errors::UnknownAttribute, "Attribute #{attr_name} does not exist in #{model_class}"
          end
        end
      end
    end
  end
end
