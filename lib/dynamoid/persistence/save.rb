# frozen_string_literal: true

module Dynamoid
  module Persistence
    # @private
    class Save
      def self.call(model, **options)
        new(model, **options).call
      end

      def initialize(model, touch: nil)
        @model = model
        @touch = touch # touch=false means explicit disabling of updating the `updated_at` attribute
      end

      def call
        @model.hash_key = SecureRandom.uuid if @model.hash_key.blank?

        return true unless @model.changed?

        @model.created_at ||= DateTime.now.in_time_zone(Time.zone) if @model.class.timestamps_enabled?

        if @model.class.timestamps_enabled? && @model.changed? && !@model.updated_at_changed? && @touch != false
          @model.updated_at = DateTime.now.in_time_zone(Time.zone)
        end

        # Add an optimistic locking check if the lock_version column exists
        if @model.class.attributes[:lock_version]
          @model.lock_version = (@model.lock_version || 0) + 1
        end

        attributes_dumped = Dumping.dump_attributes(@model.attributes, @model.class.attributes)
        Dynamoid.adapter.write(@model.class.table_name, attributes_dumped, conditions_for_write)

        @model.new_record = false
        true
      rescue Dynamoid::Errors::ConditionalCheckFailedException => e
        if @model.new_record?
          raise Dynamoid::Errors::RecordNotUnique.new(e, @model)
        else
          raise Dynamoid::Errors::StaleObjectError.new(@model, 'persist')
        end
      end

      private

      # Should be called after incrementing `lock_version` attribute
      def conditions_for_write
        conditions = {}

        # Add an 'exists' check to prevent overwriting existing records with new ones
        if @model.new_record?
          conditions[:unless_exists] = [@model.class.hash_key]
          if @model.range_key
            conditions[:unless_exists] << @model.range_key
          end
        end

        # Add an optimistic locking check if the lock_version column exists
        if @model.class.attributes[:lock_version]
          # Uses the original lock_version value from Dirty API
          # in case user changed 'lock_version' manually
          if @model.changes[:lock_version][0]
            conditions[:if] ||= {}
            conditions[:if][:lock_version] = @model.changes[:lock_version][0]
          end
        end

        conditions
      end
    end
  end
end
