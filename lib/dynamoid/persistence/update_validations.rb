# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    module UpdateValidations
      def self.validate_attributes_exist(model_class, attributes)
        model_attributes = model_class.attributes.keys

        attributes.each_key do |name|
          unless model_attributes.include?(name)
            raise Dynamoid::Errors::UnknownAttribute.new(model_class, name)
          end
        end
      end
    end
  end
end
