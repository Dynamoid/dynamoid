# frozen_string_literal: true

module Dynamoid
  module Tasks
    module Database
      module_function

      # Create any new tables for the models. Existing tables are not
      # modified.
      def create_tables
        results = { created: [], existing: [] }
        # We can't quite rely on Dynamoid.included_models alone, we need to select only viable models
        Dynamoid.included_models.reject { |m| m.base_class.try(:name).blank? }.uniq(&:table_name).each do |model|
          if Dynamoid.adapter.list_tables.include? model.table_name
            results[:existing] << model.table_name
          else
            model.create_table
            results[:created] << model.table_name
          end
        end
        results
      end

      # Is the DynamoDB reachable?
      def ping
        Dynamoid.adapter.list_tables
        true
      end
    end
  end
end
