# frozen_string_literal: true

require_relative 'base'

module Dynamoid
  module Transactions
    class Mutation
      # @private
      class Import < Base
        def initialize(model_class, array_of_attributes)
          super()

          @model_class = model_class
          @models = array_of_attributes.map do |attributes|
            attributes = attributes.symbolize_keys

            if @model_class.timestamps_enabled?
              time_now = DateTime.now.in_time_zone(Time.zone)
              attributes[:created_at] ||= time_now
              attributes[:updated_at] ||= time_now
            end

            model = @model_class.build(attributes)
            model.hash_key = SecureRandom.uuid if model.hash_key.nil?
            model
          end
        end

        def on_registration
          @models.each do |model|
            validate_primary_key!(model)
          end
        end

        def on_commit
          @models.each do |model|
            model.clear_changes_information
            model.new_record = false
            model.run_callbacks(:commit)
          end
        end

        def on_rollback
          @models.each do |model|
            model.run_callbacks(:rollback)
          end
        end

        def aborted?
          false
        end

        def skipped?
          @models.empty?
        end

        def observable_by_user_result
          @models
        end

        def action_requests
          @models.map do |model|
            attributes_dumped = Dynamoid::Dumping.dump_attributes(model.attributes, @model_class.attributes)
            attributes_dumped = sanitize_item(attributes_dumped)

            {
              put: {
                item: attributes_dumped,
                table_name: @model_class.table_name
              }
            }
          end
        end

        private

        def validate_primary_key!(model)
          raise Dynamoid::Errors::MissingHashKey if model.hash_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key? && model.range_value.nil?
        end
      end
    end
  end
end
