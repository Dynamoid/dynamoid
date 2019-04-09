# frozen_string_literal: true

require 'dynamoid'
require 'rake/tasklib'

module Dynamoid
  module Tasks
    class Database < Rake::TaskLib

      # Initializes the database rake tasks.
      def initialize
        define
      end

      # Defines the database rake tasks.
      def define
        namespace :dynamoid do
          desc 'Creates DynamoDB tables, one for each of your Dynamoid models - does not modify pre-existing tables'
          task create_tables: :environment do
            # Load models so Dynamoid will be able to discover tables expected.
            Dir[File.join(Dynamoid::Config.models_dir, '**/*.rb')].sort.each { |file| require file }
            if Dynamoid.included_models.any?
              tables = create_tables
              result = tables[:created].map { |c| "#{c} created" } + tables[:existing].map { |e| "#{e} already exists" }
              result.sort.each { |r| puts r }
            else
              puts 'Dynamoid models are not loaded, or you have no Dynamoid models.'
            end
          end

          desc 'Tests if the DynamoDB instance can be contacted using your configuration'
          task ping: :environment do
            success = false
            failure_reason = nil

            begin
              ping
              success = true
            rescue StandardError => e
              failure_reason = e.message
            end

            msg = "Connection to DynamoDB #{success ? 'OK' : 'FAILED'}"
            msg << if Dynamoid.config.endpoint
                     " at local endpoint '#{Dynamoid.config.endpoint}'"
            else
              ' at remote AWS endpoint'
            end
            msg << ", reason being '#{failure_reason}'" unless success
            puts msg
          end
        end
      end

      # Create any new tables for the models. Existing tables are not
      # modified.
      def create_tables
        results = { created: [], existing: [] }
        # We can't quite rely on Dynamoid.included_models alone, we need to select only viable models
        Dynamoid.included_models.reject { |m| m.base_class.try(:name).blank? }.uniq(&:table_name).each do |model|
          if Dynamoid.adapter.list_tables.include? model.table_name
            results[:existing] << model.table_name
          else
            model.create_table(sync: true)
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
