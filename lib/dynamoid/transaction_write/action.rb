# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class Action
      VALID_OPTIONS = %i[skip_callbacks skip_validation raise_validation_error].freeze
      attr_accessor :model, :attributes, :options, :additions, :deletions, :removals

      def initialize(model_or_model_class, attributes = {}, options = {})
        if model_or_model_class.is_a?(Dynamoid::Document)
          self.model = model_or_model_class
        else
          @model_class = model_or_model_class
        end
        self.attributes = attributes
        self.options = options || {}
        self.additions = {}
        self.deletions = {}
        self.removals = []
        invalid_keys = self.options.keys - VALID_OPTIONS
        raise ArgumentError, "Invalid options found: '#{invalid_keys}'" if invalid_keys.present?

        yield(self) if block_given?
      end

      def model_class
        model&.class || @model_class
      end

      # returns hash_key from the model if it exists or first element from id
      def hash_key
        return model.hash_key if model

        attributes[model_class.hash_key]
      end

      # returns range_key from the model if it exists or second element from id, or nil
      def range_key
        return nil unless model_class.range_key?
        return model.attributes[model_class.range_key] if model

        attributes[model_class.range_key]
      end

      # sets a value in the attributes
      def set(values)
        attributes.merge!(values)
      end

      # increments a number or adds to a set, starts at 0 or [] if it doesn't yet exist
      def add(values)
        additions.merge!(values)
      end

      # deletes a value or values from a set type or simply sets a field to nil
      def delete(field_or_values)
        if field_or_values.is_a?(Hash)
          deletions.merge!(field_or_values)
        else
          # adds to array of fields for use in REMOVE update expression
          removals << field_or_values
        end
      end

      def find_from_attributes(model_or_model_class, attributes)
        model_class = model_or_model_class.is_a?(Dynamoid::Document) ? model_or_model_class.class : model_or_model_class
        if attributes.is_a?(Hash)
          raise Dynamoid::Errors::MissingHashKey unless attributes[model_class.hash_key].present?

          model_class.find(attributes[model_class.hash_key],
                           range_key: model_class.range_key? ? attributes[model_class.range_key] : nil,
                           consistent_read: true)
        else
          model_class.find(attributes, consistent_read: true)
        end
      end

      def skip_callbacks?
        !!options[:skip_callbacks]
      end

      def skip_validation?
        !!options[:skip_validation]
      end

      def valid?
        model&.valid?
      end

      def raise_validation_error?
        !!options[:raise_validation_error]
      end

      def run_callbacks
        yield if block_given?
      end

      def changes_applied
        !!model&.changes_applied
      end

      def add_timestamps(attributes, skip_created_at: false)
        return attributes if options[:skip_timestamps] || !model_class&.timestamps_enabled?

        result = attributes.clone
        timestamp = DateTime.now.in_time_zone(Time.zone)
        result[:created_at] ||= timestamp unless skip_created_at
        result[:updated_at] ||= timestamp
        result
      end

      def touch_model_timestamps(skip_created_at: false)
        return if !model || options[:skip_timestamps] || !model_class.timestamps_enabled?

        timestamp = DateTime.now.in_time_zone(Time.zone)
        model.updated_at = timestamp
        model.created_at ||= timestamp unless skip_created_at
      end

      def write_attributes_to_model
        return unless model && attributes.present?

        attributes.each { |attribute, value| model.write_attribute(attribute, value) }
      end

      # copied from the protected method in AwsSdkV3
      def sanitize_item(attributes)
        config_value = Dynamoid.config.store_attribute_with_nil_value
        store_attribute_with_nil_value = config_value.nil? ? false : !!config_value

        attributes.reject do |_, v|
          ((v.is_a?(Set) || v.is_a?(String)) && v.empty?) ||
            (!store_attribute_with_nil_value && v.nil?)
        end.transform_values do |v|
          v.is_a?(Hash) ? v.stringify_keys : v
        end
      end

      def to_h
        raise 'override me'
      end
    end
  end
end
