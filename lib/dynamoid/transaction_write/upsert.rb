# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Upsert < Action
      # Upsert is just like Update buts skips the existence check so a new record can be created when it's missing.
      # No callbacks.
      def initialize(model_or_model_class, attributes, options = {})
        super

        write_attributes_to_model

        raise Dynamoid::Errors::MissingHashKey unless hash_key.present?
        raise Dynamoid::Errors::MissingRangeKey unless !model_class.range_key? || range_key.present?
      end

      # no callbacks are run

      # only run validations if a model has been provided
      def valid?
        model ? model.valid? : true
      end

      def to_h
        if model
          # model.hash_key = SecureRandom.uuid if model.hash_key.blank?
          touch_model_timestamps(skip_created_at: true)
          changes = model.changes.map { |k, v| [k.to_sym, v[1]] }.to_h # hash of dirty attributes
        else
          changes = attributes.clone || {}
          # changes[model_class.hash_key] = SecureRandom.uuid
          changes = add_timestamps(changes, skip_created_at: true)
        end
        changes.delete(model_class.hash_key) # can't update id!
        changes.delete(model_class.range_key) if model_class.range_key?
        item = Dynamoid::Dumping.dump_attributes(changes, model_class.attributes)

        # set 'key' that is used to look up record for updating
        key = { model_class.hash_key => hash_key }
        key[model_class.range_key] = range_key if model_class.range_key?

        # e.g. "SET #updated_at = :updated_at ADD record_count :i"
        item_keys = item.keys
        update_expression = "SET #{item_keys.each_with_index.map { |_k, i| "#_n#{i} = :_s#{i}" }.join(', ')}"

        # e.g. {":updated_at" => 1645453.234, ":i" => 1}
        expression_attribute_values = item_keys.each_with_index.map { |k, i| [":_s#{i}", item[k]] }.to_h
        expression_attribute_names = {}

        update_expression = set_additions(expression_attribute_values, update_expression)
        update_expression = set_deletions(expression_attribute_values, update_expression)
        expression_attribute_names, update_expression = set_removals(expression_attribute_names, update_expression)

        # only alias names for fields in models, other values such as for ADD do not have them
        # e.g. {"#updated_at" => "updated_at"}
        # attribute_keys_in_model = item_keys.intersection(model_class.attributes.keys)
        # expression_attribute_names = attribute_keys_in_model.map{|k| ["##{k}","#{k}"]}.to_h
        expression_attribute_names.merge!(item_keys.each_with_index.map { |k, i| ["#_n#{i}", k.to_s] }.to_h)

        result = {
          update: {
            key: key,
            table_name: model_class.table_name,
            update_expression: update_expression,
            expression_attribute_values: expression_attribute_values
          }
        }
        result[:update][:expression_attribute_names] = expression_attribute_names if expression_attribute_names.present?

        result
      end

      private

      # adds all of the ADD statements to the update_expression and returns it
      def set_additions(expression_attribute_values, update_expression)
        return update_expression unless additions.present?

        # ADD statements can be used to increment a counter:
        # txn.update!(UserCount, "UserCount#Red", {}, options: {add: {record_count: 1}})
        add_keys = additions.keys
        update_expression += " ADD #{add_keys.each_with_index.map { |k, i| "#{k} :_a#{i}" }.join(', ')}"
        # convert any enumerables into sets
        add_values = additions.transform_values do |v|
          if !v.is_a?(Set) && v.is_a?(Enumerable)
            Set.new(v)
          else
            v
          end
        end
        add_keys.each_with_index { |k, i| expression_attribute_values[":_a#{i}"] = add_values[k] }
        update_expression
      end

      # adds all of the DELETE statements to the update_expression and returns it
      def set_deletions(expression_attribute_values, update_expression)
        return update_expression unless deletions.present?

        delete_keys = deletions.keys
        update_expression += " DELETE #{delete_keys.each_with_index.map { |k, i| "#{k} :_d#{i}" }.join(', ')}"
        # values must be sets
        delete_values = deletions.transform_values do |v|
          if v.is_a?(Set)
            v
          else
            Set.new(v.is_a?(Enumerable) ? v : [v])
          end
        end
        delete_keys.each_with_index { |k, i| expression_attribute_values[":_d#{i}"] = delete_values[k] }
        update_expression
      end

      # adds all of the removals as a REMOVE clause
      def set_removals(expression_attribute_names, update_expression)
        return expression_attribute_names, update_expression unless removals.present?

        update_expression += " REMOVE #{removals.each_with_index.map { |_k, i| "#_r#{i}" }.join(', ')}"
        expression_attribute_names = expression_attribute_names.merge(
          removals.each_with_index.map { |k, i| ["#_r#{i}", k.to_s] }.to_h
        )
        [expression_attribute_names, update_expression]
      end
    end
  end
end
