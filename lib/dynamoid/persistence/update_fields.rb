# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    class UpdateFields
      def self.call(*args, **options)
        new(*args, **options).call
      end

      def initialize(model_class, partition_key:, sort_key:, attributes:, conditions:)
        @model_class = model_class
        @partition_key = partition_key
        @sort_key = sort_key
        @attributes = attributes.symbolize_keys
        @conditions = conditions
      end

      def call
        UpdateValidations.validate_attributes_exist(@model_class, @attributes)

        if @model_class.timestamps_enabled?
          @attributes[:updated_at] ||= DateTime.now.in_time_zone(Time.zone)
        end

        raw_attributes = update_item
        @model_class.new(undump_attributes(raw_attributes))
      rescue Dynamoid::Errors::ConditionalCheckFailedException
      end

      private

      def update_item
        Dynamoid.adapter.update_item(@model_class.table_name, @partition_key, options_to_update_item) do |t|
          @attributes.each do |k, v|
            value_casted = TypeCasting.cast_field(v, @model_class.attributes[k])
            value_dumped = Dumping.dump_field(value_casted, @model_class.attributes[k])
            t.set(k => value_dumped)
          end
        end
      end

      def undump_attributes(attributes)
        Undumping.undump_attributes(attributes, @model_class.attributes)
      end

      def options_to_update_item
        options = {}

        if @model_class.range_key
          value_casted = TypeCasting.cast_field(@sort_key, @model_class.attributes[@model_class.range_key])
          value_dumped = Dumping.dump_field(value_casted, @model_class.attributes[@model_class.range_key])
          options[:range_key] = value_dumped
        end

        conditions = @conditions.deep_dup
        conditions[:if_exists] ||= {}
        conditions[:if_exists][@model_class.hash_key] = @partition_key
        options[:conditions] = conditions

        options
      end
    end
  end
end
