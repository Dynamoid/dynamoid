# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class Upsert
      def initialize(model_class, attributes, **options)
        @model_class = model_class
        @attributes = attributes
        @options = options
      end

      def on_registration
        validate_primary_key!
      end

      def on_completing
      end

      def aborted?
        false
      end

      def skip?
        attributes_to_assign = @attributes.except(@model_class.hash_key, @model_class.range_key)
        attributes_to_assign.empty? && !@model_class.timestamps_enabled?
      end

      def observable_by_user_result
        nil
      end

      def action_request
        changes = @attributes.dup
        # changes[@model_class.hash_key] = SecureRandom.uuid
        changes = add_timestamps(changes, skip_created_at: true)

        changes.delete(@model_class.hash_key) # can't update id!
        changes.delete(@model_class.range_key) if @model_class.range_key?
        item = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

        # set 'key' that is used to look up record for updating
        key = { @model_class.hash_key => hash_key }
        key[@model_class.range_key] = range_key if @model_class.range_key?

        # e.g. "SET #updated_at = :updated_at ADD record_count :i"
        item_keys = item.keys
        update_expression = "SET #{item_keys.each_with_index.map { |_k, i| "#_n#{i} = :_s#{i}" }.join(', ')}"

        # e.g. {":updated_at" => 1645453.234, ":i" => 1}
        expression_attribute_values = item_keys.each_with_index.map { |k, i| [":_s#{i}", item[k]] }.to_h
        expression_attribute_names = {}

        # only alias names for fields in models, other values such as for ADD do not have them
        # e.g. {"#updated_at" => "updated_at"}
        # attribute_keys_in_model = item_keys.intersection(@model_class.attributes.keys)
        # expression_attribute_names = attribute_keys_in_model.map{|k| ["##{k}","#{k}"]}.to_h
        expression_attribute_names.merge!(item_keys.each_with_index.map { |k, i| ["#_n#{i}", k.to_s] }.to_h)

        result = {
          update: {
            key: key,
            table_name: @model_class.table_name,
            update_expression: update_expression,
            expression_attribute_names: expression_attribute_names,
            expression_attribute_values: expression_attribute_values
          }
        }

        result
      end

      private

      def validate_primary_key!
        raise Dynamoid::Errors::MissingHashKey if hash_key.nil?
        raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && range_key.nil?
      end

      def hash_key
        @attributes[@model_class.hash_key]
      end

      def range_key
        return nil unless @model_class.range_key?
        @attributes[@model_class.range_key]
      end

      def add_timestamps(attributes, skip_created_at: false)
        return attributes unless @model_class.timestamps_enabled?

        result = attributes.clone
        timestamp = DateTime.now.in_time_zone(Time.zone)
        result[:created_at] ||= timestamp unless skip_created_at
        result[:updated_at] ||= timestamp
        result
      end
    end
  end
end
