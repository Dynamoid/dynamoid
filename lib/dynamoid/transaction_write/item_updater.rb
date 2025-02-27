# frozen_string_literal: true

module Dynamoid
  class TransactionWrite
    class ItemUpdater
      attr_reader :attributes_to_set, :attributes_to_add, :attributes_to_delete, :attributes_to_remove

      def initialize(model_class)
        @model_class = model_class

        @attributes_to_set = {}
        @attributes_to_add = {}
        @attributes_to_delete = {}
        @attributes_to_remove = []
      end

      def empty?
        [@attributes_to_set, @attributes_to_add, @attributes_to_delete, @attributes_to_remove].all?(&:empty?)
      end

      def set(attributes)
        validate_attribute_names!(attributes.keys)
        @attributes_to_set.merge!(attributes)
      end

      # adds to array of fields for use in REMOVE update expression
      def remove(*names)
        validate_attribute_names!(names)
        @attributes_to_remove += names
      end

      # increments a number or adds to a set, starts at 0 or [] if it doesn't yet exist
      def add(attributes)
        validate_attribute_names!(attributes.keys)
        @attributes_to_add.merge!(attributes)
      end

      # deletes a value or values from a set
      def delete(attributes)
        validate_attribute_names!(attributes.keys)
        @attributes_to_delete.merge!(attributes)
      end

      private

      def validate_attribute_names!(names)
        names.each do |name|
          unless @model_class.attributes[name]
            raise Dynamoid::Errors::UnknownAttribute.new(@model_class, name)
          end
        end
      end
    end
  end
end
