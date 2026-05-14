# frozen_string_literal: true

module Dynamoid
  module Transactions
    class Mutation
      # @private
      class UpdateRequestBuilder
        attr_writer :hash_key, :range_key, :condition_expression

        def initialize(model_class)
          @model_class = model_class

          @attributes_to_set = {}
          @attributes_to_add = {}
          @attributes_to_delete = {}
          @attributes_to_remove = []
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

        def set_attributes(attributes) # rubocop:disable Naming/AccessorMethodName
          @attributes_to_set.merge!(attributes)
        end

        def add_value(name, value)
          @attributes_to_add[name] = value
        end

        def delete_value(name, value)
          @attributes_to_delete[name] = value
        end

        def remove_attributes(names)
          @attributes_to_remove.concat(names)
        end

        def request
          key = { @model_class.hash_key => @hash_key }
          key[@model_class.range_key] = @range_key if @model_class.range_key?

          # Build UpdateExpression and keep names and values placeholders mapping
          # in ExpressionAttributeNames and ExpressionAttributeValues.
          update_expression_statements = []
          expression_attribute_names = @extra_attribute_names.dup
          expression_attribute_values = @extra_attribute_values.dup
          name_placeholder = '#_n0'
          value_placeholder = ':_v0'

          unless @attributes_to_set.empty?
            statements = []

            @attributes_to_set.each do |name, value|
              statements << "#{name_placeholder} = #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "SET #{statements.join(', ')}"
          end

          unless @attributes_to_add.empty?
            statements = []

            @attributes_to_add.each do |name, value|
              statements << "#{name_placeholder} #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "ADD #{statements.join(', ')}"
          end

          unless @attributes_to_delete.empty?
            statements = []

            @attributes_to_delete.each do |name, value|
              statements << "#{name_placeholder} #{value_placeholder}"

              expression_attribute_names[name_placeholder] = name
              expression_attribute_values[value_placeholder] = value

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "DELETE #{statements.join(', ')}"
          end

          unless @attributes_to_remove.empty?
            name_placeholders = []

            @attributes_to_remove.each do |name|
              name_placeholders << name_placeholder

              expression_attribute_names[name_placeholder] = name

              name_placeholder = name_placeholder.succ
              value_placeholder = value_placeholder.succ
            end

            update_expression_statements << "REMOVE #{name_placeholders.join(', ')}"
          end

          update_expression = update_expression_statements.join(' ')

          {
            update: {
              key: key,
              table_name: @model_class.table_name,
              update_expression: update_expression,
              expression_attribute_names: expression_attribute_names,
              expression_attribute_values: expression_attribute_values,
              condition_expression: @condition_expression
            }
          }
        end
      end
    end
  end
end
