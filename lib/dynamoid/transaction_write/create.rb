# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Create < Action
      # model is created if not otherwise specified so callbacks can be run
      def initialize(model_or_model_class, attributes = {}, options = {})
        model = if model_or_model_class.is_a?(Dynamoid::Document)
                  model_or_model_class
                else
                  model_or_model_class.new(attributes)
                end
        super(model, attributes, options)

        # don't initialize hash key here, callbacks haven't run yet
      end

      def run_callbacks
        # model always exists
        model.run_callbacks(:save) do
          model.run_callbacks(:create) do
            model.run_callbacks(:validate) do
              yield if block_given?
            end
          end
        end
      end

      def to_h
        model.hash_key = SecureRandom.uuid if model.hash_key.blank?
        write_attributes_to_model
        touch_model_timestamps
        # model always exists
        item = Dynamoid::Dumping.dump_attributes(model.attributes, model_class.attributes)

        condition = "attribute_not_exists(#{model_class.hash_key})"
        condition += " and attribute_not_exists(#{model_class.range_key})" if model_class.range_key? # needed?
        result = {
          put: {
            item: sanitize_item(item),
            table_name: model_class.table_name,
          }
        }
        result[:put][:condition_expression] = condition

        result
      end
    end
  end
end
