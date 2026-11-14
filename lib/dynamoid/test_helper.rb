# frozen_string_literal: true

module Dynamoid
  module TestHelper
    module_function

    # Provision tables for all loaded models (or specified models).
    #
    #   Dynamoid::TestHelper.create_tables
    #   Dynamoid::TestHelper.create_tables(User, Post)
    #
    def create_tables(*models)
      if models.empty?
        models_dir = Dynamoid.config.models_dir

        if models_dir
          unless Dir.exist?(models_dir)
            raise Dynamoid::Errors::Error, "Dynamoid.config.models_dir #{models_dir.inspect} does not exist"
          end

          Dir[File.join(models_dir, '**/*.rb')].sort.each { |f| require f }
        end

        models = Dynamoid.included_models
      end

      models.uniq(&:table_name).each do |model|
        model.create_table(sync: true)
      end
    end

    # Fast item cleanup between tests.
    #
    #   Dynamoid::TestHelper.truncate_tables
    #   Dynamoid::TestHelper.truncate_tables(User, Post)
    #
    def truncate_tables(*models)
      models = Dynamoid.included_models if models.empty?

      models.map(&:table_name).uniq.each do |table|
        Dynamoid.adapter.truncate(table)
      end
    end

    # Delete all tables belonging to the current namespace.
    #
    #   Dynamoid::TestHelper.drop_tables
    #
    def drop_tables
      namespace = Dynamoid.config.namespace
      if namespace.to_s.empty?
        raise Dynamoid::Errors::Error, 'Dynamoid.config.namespace must be set to prevent dropping non-test tables'
      end

      prefix = "#{namespace}_"
      tables = Dynamoid.adapter.list_tables.select { |t| t.start_with?(prefix) }

      tables.each { |t| Dynamoid.adapter.delete_table(t) }
      Dynamoid.adapter.tables.clear
    end
  end
end
