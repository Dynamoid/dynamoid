# frozen_string_literal: true

require_relative 'base'
require_relative 'update_request_builder'
require 'dynamoid/persistence/update_validations'

module Dynamoid
  module Transactions
    class Mutation
      class UpdateFields < Base
        def initialize(model_class, hash_key, range_key, attributes, &block)
          super()

          @model_class = model_class
          @hash_key = hash_key
          @range_key = range_key
          @attributes = attributes || {}
          @block = block
        end

        def on_registration
          validate_primary_key!
          Dynamoid::Persistence::UpdateValidations.validate_attributes_exist(@model_class, @attributes)

          if @block
            @item_updater = ItemUpdater.new(@model_class)
            @block.call(@item_updater)
          end
        end

        def on_commit; end

        def on_rollback; end

        def aborted?
          false
        end

        def skipped?
          @attributes.empty? && (!@item_updater || @item_updater.empty?)
        end

        def observable_by_user_result
          nil
        end

        def action_request
          builder = UpdateRequestBuilder.new(@model_class)

          # primary key to look up an item to update
          builder.hash_key = dump_attribute(@model_class.hash_key, @hash_key)
          builder.range_key = dump_attribute(@model_class.range_key, @range_key) if @model_class.range_key?

          # require primary key to exist
          builder.add_expression_attribute_name('#_h', @model_class.hash_key)
          condition_expression = 'attribute_exists(#_h)'

          if @model_class.range_key?
            builder.add_expression_attribute_name('#_r', @model_class.range_key)
            condition_expression += ' AND attribute_exists(#_r)'
          end
          builder.condition_expression = condition_expression

          # changed attributes to persist
          changes = add_timestamps(@attributes, skip_created_at: true)
          changes_dumped = Dynamoid::Dumping.dump_attributes(changes, @model_class.attributes)

          if Dynamoid.config.store_attribute_with_nil_value
            builder.set_attributes(changes_dumped)
          else
            nil_attributes = changes_dumped.select { |_, v| v.nil? }
            non_nil_attributes = changes_dumped.reject { |_, v| v.nil? } # rubocop:disable Style/PartitionInsteadOfDoubleSelect

            builder.remove_attributes(nil_attributes.keys)
            builder.set_attributes(non_nil_attributes)
          end

          # given a block
          if @item_updater
            builder.set_attributes(@item_updater.attributes_to_set)
            builder.remove_attributes(@item_updater.attributes_to_remove)

            @item_updater.attributes_to_add.each do |name, value|
              # The ADD section in UpdateExpressions requires values to be a
              # set to update a set attribute.
              # Allow specifying values as any Enumerable collection (e.g. Array).
              # Allow a single value not wrapped into a Set
              if @model_class.attributes[name][:type] == :set
                value = value.is_a?(Enumerable) ? Set.new(value) : Set[value]
              end

              builder.add_value(name, value)
            end

            @item_updater.attributes_to_delete.each do |name, value|
              # The DELETE section in UpdateExpressions requires values to be a
              # set to update a set attribute.
              # Allow specifying values as any Enumerable collection (e.g. Array).
              # Allow a single value not wrapped into a Set
              value = value.is_a?(Enumerable) ? Set.new(value) : Set[value]

              builder.delete_value(name, value)
            end
          end

          builder.request
        end

        private

        def validate_primary_key!
          raise Dynamoid::Errors::MissingHashKey if @hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && @range_key.nil?
        end

        def add_timestamps(attributes, skip_created_at: false)
          return attributes unless @model_class.timestamps_enabled?

          result = attributes.clone
          timestamp = DateTime.now.in_time_zone(Time.zone)
          result[:created_at] ||= timestamp unless skip_created_at
          result[:updated_at] ||= timestamp
          result
        end

        def dump_attribute(name, value)
          options = @model_class.attributes[name]
          Dumping.dump_field(value, options)
        end
      end
    end
  end
end
