# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    class ItemUpdaterWithCastingAndDumping
      def initialize(model_class, item_updater)
        @model_class = model_class
        @item_updater = item_updater
      end

      def add(attributes)
        @item_updater.add(cast_and_dump(attributes))
      end

      def set(attributes)
        @item_updater.set(cast_and_dump(attributes))
      end

      private

      def cast_and_dump(attributes)
        casted_and_dumped = {}

        attributes.each do |name, value|
          value_casted = TypeCasting.cast_field(value, @model_class.attributes[name])
          value_dumped = Dumping.dump_field(value_casted, @model_class.attributes[name])

          casted_and_dumped[name] = value_dumped
        end

        casted_and_dumped
      end
    end
  end
end
