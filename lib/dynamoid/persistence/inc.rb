# frozen_string_literal: true

require_relative 'item_updater_with_casting_and_dumping'

module Dynamoid
  module Persistence
    # @private
    class Inc
      def self.call(model_class, hash_key, range_key = nil, counters)
        new(model_class, hash_key, range_key, counters).call
      end

      # rubocop:disable Style/OptionalArguments
      def initialize(model_class, hash_key, range_key = nil, counters)
        @model_class = model_class
        @hash_key = hash_key
        @range_key = range_key
        @counters = counters
      end
      # rubocop:enable Style/OptionalArguments

      def call
        touch = @counters.delete(:touch)
        hash_key_dumped = cast_and_dump(@model_class.hash_key, @hash_key)

        @model_class.adapter.update_item(@model_class.table_name, hash_key_dumped, update_item_options) do |t|
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
      end

      private

      def update_item_options
        if @model_class.range_key
          range_key_dumped = cast_and_dump(@model_class.range_key, @range_key)
          { range_key: range_key_dumped }
        else
          {}
        end
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
