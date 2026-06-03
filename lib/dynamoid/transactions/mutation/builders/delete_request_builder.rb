# frozen_string_literal: true

module Dynamoid
  module Transactions
    class Mutation
      # @private
      module Builders
        class DeleteRequestBuilder
          attr_writer :hash_key, :range_key, :condition_expression

          def initialize(model_class)
            @model_class = model_class
            @condition_expression = nil
            @extra_attribute_names = {}
            @extra_attribute_values = {}
          end

          def add_expression_attribute_name(placeholder, name)
            @extra_attribute_names[placeholder] = name
          end

          def add_expression_attribute_value(placeholder, value)
            @extra_attribute_values[placeholder] = value
          end

          def request
            key = { @model_class.hash_key => @hash_key }
            key[@model_class.range_key] = @range_key if @model_class.range_key?

            {
              delete: {
                key: key,
                table_name: @model_class.table_name,
                expression_attribute_names: @extra_attribute_names.presence,
                expression_attribute_values: @extra_attribute_values.presence,
                condition_expression: @condition_expression
              }.compact
            }
          end
        end
      end
    end
  end
end
