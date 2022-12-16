# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    unless Dynamoid.adapter.tables.empty?
      Dynamoid.adapter.list_tables.each do |table|
        Dynamoid.adapter.delete_table(table) if /^#{Dynamoid::Config.namespace}/.match?(table)
      end
      Dynamoid.adapter.tables.clear
    end
  end
end
