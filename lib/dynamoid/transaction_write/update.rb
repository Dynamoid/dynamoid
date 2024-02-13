# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Update < UpdateUpsert
      # model is found if not otherwise specified so callbacks can be run
      def initialize(model_or_model_class, attributes, options = {})
        model = if model_or_model_class.is_a?(Dynamoid::Document)
                  model_or_model_class
                else
                  find_from_attributes(model_or_model_class, attributes)
                end
        super(model, attributes, options)
      end

      def run_callbacks
        unless model
          yield if block_given?
          return
        end
        model.run_callbacks(:save) do
          model.run_callbacks(:update) do
            model.run_callbacks(:validate) do
              yield if block_given?
            end
          end
        end
      end
    end
  end
end
