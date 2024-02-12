# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class UpdateUpsert < Action
      def initialize(model_or_model_class, attributes = {}, options = {})
        super(model_or_model_class, attributes, options)

        write_attributes_to_model
      end

      # shared by Update and Upsert
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

        if options[:add] # not yet documented or supported, may change in a future release
          # ADD statements can be used to increment a counter:
          # txn.update!(UserCount, "UserCount#Red", {}, options: {add: {record_count: 1}})
          add_keys = options[:add].keys
          update_expression += " ADD #{add_keys.each_with_index.map { |k, i| "#{k} :_a#{i}" }.join(', ')}"
          add_keys.each_with_index { |k, i| expression_attribute_values[":_a#{i}"] = options[:add][k] }
        end

        # only alias names for fields in models, other values such as for ADD do not have them
        # e.g. {"#updated_at" => "updated_at"}
        # attribute_keys_in_model = item_keys.intersection(model_class.attributes.keys)
        # expression_attribute_names = attribute_keys_in_model.map{|k| ["##{k}","#{k}"]}.to_h
        expression_attribute_names = item_keys.each_with_index.map { |k, i| ["#_n#{i}", k.to_s] }.to_h

        condition_expression = "attribute_exists(#{model_class.hash_key})" # fail if record is missing
        condition_expression += " and attribute_exists(#{model_class.range_key})" if model_class.range_key? # needed?

        result = {
          update: {
            key: key,
            table_name: model_class.table_name,
            update_expression: update_expression,
            expression_attribute_values: expression_attribute_values
          }
        }
        result[:update][:expression_attribute_names] = expression_attribute_names if expression_attribute_names.present?
        result[:update][:condition_expression] = condition_expression unless options[:skip_existence_check]

        result
      end
    end
  end
end
