# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Delete < Action
      # a model is not needed since callbacks are not run
      def initialize(model_or_model_class, key_or_attributes = {}, options = {})
        super(model_or_model_class, {}, options)
        self.attributes = if key_or_attributes.is_a?(Hash)
                            key_or_attributes
                          else
                            {
                              model_class.hash_key => key_or_attributes
                            }
                          end
        raise Dynamoid::Errors::MissingHashKey unless hash_key.present?
        raise Dynamoid::Errors::MissingRangeKey unless !model_class.range_key? || range_key.present?
      end

      def skip_validation?
        true
      end

      def to_h
        key = { model_class.hash_key => hash_key }
        key[model_class.range_key] = range_key if model_class.range_key?
        {
          delete: {
            key: key,
            table_name: model_class.table_name
          }
        }
      end
    end
  end
end
