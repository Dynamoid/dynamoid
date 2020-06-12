# frozen_string_literal: true

module Dynamoid
  module Persistence
    class Upsert
      def self.call(*args)
        new(args.first, **args.last).call
      end

      def initialize(model_class, partition_key:, sort_key:, attributes:, conditions:)
        @model_class = model_class
        @partition_key = partition_key
        @sort_key = sort_key
        @attributes = attributes.symbolize_keys
        @conditions = conditions
      end

      def call
        if Dynamoid::Config.timestamps
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

      def options_to_update_item
        options = {}

        if @model_class.range_key
          value_casted = TypeCasting.cast_field(@sort_key, @model_class.attributes[@model_class.range_key])
          value_dumped = Dumping.dump_field(value_casted, @model_class.attributes[@model_class.range_key])
          options[:range_key] = value_dumped
        end

        options[:conditions] = @conditions
        options
      end

      def undump_attributes(raw_attributes)
        Undumping.undump_attributes(raw_attributes, @model_class.attributes)
      end
    end
  end
end
