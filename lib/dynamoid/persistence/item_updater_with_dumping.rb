# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    class ItemUpdaterWithDumping

      def initialize(model_class, item_updater)
        @model_class = model_class
        @item_updater = item_updater
      end

      def add(attributes)
        @item_updater.add(dump(attributes))
      end

      def set(attributes)
        @item_updater.set(dump(attributes))
      end

      private

      def dump(attributes)
        dumped = {}

        attributes.each do |name, value|
          dumped[name] = Dumping.dump_field(value, @model_class.attributes[name])
        end

        dumped
      end
    end
  end
end

