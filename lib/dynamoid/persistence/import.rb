# frozen_string_literal: true

require 'securerandom'

module Dynamoid
  module Persistence
    # @private
    class Import
      def self.call(model_class, array_of_attributes)
        new(model_class, array_of_attributes).call
      end

      def initialize(model_class, array_of_attributes)
        @model_class = model_class
        @array_of_attributes = array_of_attributes
      end

      def call
        models = @array_of_attributes.map(&method(:build_model))

        unless Dynamoid.config.backoff
          import(models)
        else
          import_with_backoff(models)
        end

        models.each { |d| d.new_record = false }
        models
      end

      private

      def build_model(attributes)
        attrs = attributes.symbolize_keys

        if @model_class.timestamps_enabled?
          time_now = DateTime.now.in_time_zone(Time.zone)
          attrs[:created_at] ||= time_now
          attrs[:updated_at] ||= time_now
        end

        @model_class.build(attrs).tap do |model|
          model.hash_key = SecureRandom.uuid if model.hash_key.blank?
        end
      end

      def import_with_backoff(models)
        backoff = nil
        table_name = @model_class.table_name
        items = array_of_dumped_attributes(models)

        Dynamoid.adapter.batch_write_item(table_name, items) do |has_unprocessed_items|
          if has_unprocessed_items
            backoff ||= Dynamoid.config.build_backoff
            backoff.call
          else
            backoff = nil
          end
        end
      end

      def import(models)
        Dynamoid.adapter.batch_write_item(@model_class.table_name, array_of_dumped_attributes(models))
      end

      def array_of_dumped_attributes(models)
        models.map do |m|
          Dumping.dump_attributes(m.attributes, @model_class.attributes)
        end
      end
    end
  end
end
