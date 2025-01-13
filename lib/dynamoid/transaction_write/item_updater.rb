# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class ItemUpdater
      def initialize
        @additions = {}
        @deletions = {}
        @removals = []
      end

      def empty?
        @additions.empty? && @deletions.empty? && @removals.empty?
      end

      # adds to array of fields for use in REMOVE update expression
      def remove(field)
        @removals << field
      end

      # increments a number or adds to a set, starts at 0 or [] if it doesn't yet exist
      def add(values)
        @additions.merge!(values)
      end

      # deletes a value or values from a set type or simply sets a field to nil
      def delete(field_or_values)
        if field_or_values.is_a?(Hash)
          @deletions.merge!(field_or_values)
        else
          remove(field_or_values)
        end
      end

      def merge_update_expression(expression_attribute_names, expression_attribute_values, update_expression)
        update_expression = set_additions(expression_attribute_values, update_expression)
        update_expression = set_deletions(expression_attribute_values, update_expression)
        expression_attribute_names, update_expression = set_removals(expression_attribute_names, update_expression)
        [expression_attribute_names, update_expression]
      end

      # adds all of the ADD statements to the update_expression and returns it
      def set_additions(expression_attribute_values, update_expression)
        return update_expression unless @additions.present?

        # ADD statements can be used to increment a counter:
        # txn.update!(UserCount, "UserCount#Red", {}, options: {add: {record_count: 1}})
        add_keys = @additions.keys
        add_values = transform_add_values(@additions)

        update_expression += build_add_expression(add_keys)
        add_keys.each_with_index { |k, i| expression_attribute_values[":_a#{i}"] = add_values[k] }
        update_expression
      end

      def transform_add_values(additions)
        additions.transform_values do |v|
          !v.is_a?(Set) && v.is_a?(Enumerable) ? Set.new(v) : v
        end
      end

      def build_add_expression(add_keys)
        " ADD #{add_keys.each_with_index.map { |k, i| "#{k} :_a#{i}" }.join(', ')}"
      end

      # adds all of the DELETE statements to the update_expression and returns it
      def set_deletions(expression_attribute_values, update_expression)
        return update_expression unless @deletions.present?

        update_expression += build_delete_expression(@deletions.keys)
        delete_values = prepare_delete_values(@deletions)

        @deletions.keys.each_with_index do |key, index|
          expression_attribute_values[":_d#{index}"] = delete_values[key]
        end

        update_expression
      end

      def build_delete_expression(delete_keys)
        " DELETE #{delete_keys.each_with_index.map { |key, index| "#{key} :_d#{index}" }.join(', ')}"
      end

      def prepare_delete_values(deletions)
        deletions.transform_values(&method(:prepare_delete_values_transform))
      end

      def prepare_delete_values_transform(value)
        if value.is_a?(Set)
          value
        else
          Set.new(value.is_a?(Enumerable) ? value : [value])
        end
      end

      # adds all of the removals as a REMOVE clause
      def set_removals(expression_attribute_names, update_expression)
        return expression_attribute_names, update_expression unless @removals.present?

        update_expression += " REMOVE #{@removals.each_with_index.map { |_k, i| "#_r#{i}" }.join(', ')}"
        expression_attribute_names = expression_attribute_names.merge(
          @removals.each_with_index.map { |k, i| ["#_r#{i}", k.to_s] }.to_h
        )
        [expression_attribute_names, update_expression]
      end
    end
  end
end
