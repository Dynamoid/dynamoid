# frozen_string_literal: true

require_relative 'item_updater_with_casting_and_dumping'

module Dynamoid
  module Persistence
    # @private
    class Inc
      def self.call(model_class, partition_key, sort_key = nil, counters)
        new(model_class, partition_key, sort_key, counters).call
      end

      # rubocop:disable Style/OptionalArguments
      def initialize(model_class, partition_key, sort_key = nil, counters)
        @model_class = model_class
        @partition_key = partition_key
        @sort_key = sort_key
        @counters = counters
      end
      # rubocop:enable Style/OptionalArguments

      def call
        touch = @counters.delete(:touch)
        partition_key_dumped = cast_and_dump(@model_class.hash_key, @partition_key)
        options = update_item_options(partition_key_dumped)

        Dynamoid.adapter.update_item(@model_class.table_name, partition_key_dumped, options) do |t|
          item_updater = ItemUpdaterWithCastingAndDumping.new(@model_class, t)

          @counters.each do |name, value|
            item_updater.add(name => value)
          end

          if touch
            value = DateTime.now.in_time_zone(Time.zone)

            timestamp_attributes_to_touch(touch).each do |name|
              item_updater.set(name => value)
            end
          end
        end
      rescue Dynamoid::Errors::ConditionalCheckFailedException # rubocop:disable Lint/SuppressedException
      end

      private

      def update_item_options(partition_key_dumped)
        options = {}

        conditions = {
          if: {
            @model_class.hash_key => partition_key_dumped
          }
        }
        options[:conditions] = conditions

        if @model_class.range_key
          sort_key_dumped = cast_and_dump(@model_class.range_key, @sort_key)
          options[:range_key] = sort_key_dumped
          options[:conditions][@model_class.range_key] = sort_key_dumped
        end

        options
      end

      def timestamp_attributes_to_touch(touch)
        return [] unless touch

        names = []
        names << :updated_at if @model_class.timestamps_enabled?
        names += Array.wrap(touch) if touch != true
        names
      end

      def cast_and_dump(name, value)
        options = @model_class.attributes[name]
        value_casted = TypeCasting.cast_field(value, options)
        Dumping.dump_field(value_casted, options)
      end
    end
  end
end
