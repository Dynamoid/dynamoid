# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Destroy < Action
      # model is found if not otherwise specified so callbacks can be run
      def initialize(model_or_model_class, key_or_attributes = {}, options = {})
        model = if model_or_model_class.is_a?(Dynamoid::Document)
                  model_or_model_class
                else
                  find_from_attributes(model_or_model_class, key_or_attributes)
                end
        super(model, {}, options)
        raise Dynamoid::Errors::MissingHashKey unless hash_key.present?
        raise Dynamoid::Errors::MissingRangeKey unless !model_class.range_key? || range_key.present?
      end

      def run_callbacks
        model.run_callbacks(:destroy) do
          yield if block_given?
        end
      end

      # destroy defaults to not using validation
      def skip_validation?
        options[:skip_validation] != false
      end

      def to_h
        model.destroyed = true
        key = { model_class.hash_key => hash_key }
        key[model_class.range_key] = range_key if model_class.range_key?
        # force fast fail i.e. won't retry if record is missing
        condition_expression = "attribute_exists(#{model_class.hash_key})"
        condition_expression += " and attribute_exists(#{model_class.range_key})" if model_class.range_key? # needed?
        result = {
          delete: {
            key: key,
            table_name: model_class.table_name
          }
        }
        result[:delete][:condition_expression] = condition_expression unless options[:skip_existence_check]
        result
      end
    end
  end
end
