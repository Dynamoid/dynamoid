# frozen_string_literal: true

require 'securerandom'
module Dynamoid
  module Persistence
    # @private
    class Transact
      def self.call(model_class, set_of_operations)
        new(model_class, set_of_operations).call
      end

      def initialize(model_class, set_of_operations)
        @model_class = model_class
        @set_of_operations = set_of_operations
      end

      def call
        models = @set_of_operations.map(&method(:build_model))
        transact(models)
      end

      def build_model(attributes)
        # attrs = attributes.symbolize_keys

        type, attrib = attributes.flatten

        attrs = attrib.symbolize_keys

        operations = {}

        if @model_class.timestamps_enabled?
          time_now = DateTime.now.in_time_zone(Time.zone)
          attrs[:created_at] ||= time_now
          attrs[:updated_at] ||= time_now
        end

        @model_class.build(attrs).tap do |model|
          model.hash_key = SecureRandom.uuid if model.hash_key.blank?
          operations[type] = model
        end

        operations
      end

      def transact(models)
        Dynamoid.adapter.transact_write_items(@model_class.table_name, array_of_dumped_attributes(models))
      end

      def array_of_dumped_attributes(models)
        models.map do |m|
          key, model = m.flatten
          { key => Dumping.dump_attributes(model.attributes, @model_class.attributes) }
        end
      end
    end
  end
end
