# frozen_string_literal: true

require_relative 'item_updater_with_casting_and_dumping'

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

        @partition_key_dumped = cast_and_dump(@model_class.hash_key, @partition_key)
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
        Dynamoid.adapter.update_item(@model_class.table_name, @partition_key_dumped, options_to_update_item) do |t|
          item_updater = ItemUpdaterWithCastingAndDumping.new(@model_class, t)

          @attributes.each do |k, v|
            item_updater.set(k => v)
          end
        end
      end

      def undump_attributes(attributes)
        Undumping.undump_attributes(attributes, @model_class.attributes)
      end

      def options_to_update_item
        options = {}

        if @model_class.range_key
          range_key_dumped = cast_and_dump(@model_class.range_key, @sort_key)
          options[:range_key] = range_key_dumped
        end

        conditions = @conditions.deep_dup
        conditions[:if] ||= {}
        conditions[:if][@model_class.hash_key] = @partition_key_dumped
        options[:conditions] = conditions

        options
      end

      def cast_and_dump(name, value)
        options = @model_class.attributes[name]
        value_casted = TypeCasting.cast_field(value, options)
        Dumping.dump_field(value_casted, options)
      end
    end
  end
end
