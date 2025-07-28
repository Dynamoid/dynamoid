# frozen_string_literal: true

require 'spec_helper'

describe 'Multi-config E2E Integration' do
  before do
    Dynamoid::MultiConfig.clear_all

    Dynamoid::MultiConfig.configure do |config|
      config.add_config(:primary) do |c|
        c.namespace = 'primary_test_e2e'
        c.region = 'us-east-1'
        c.endpoint = 'http://localhost:8000' # DynamoDB Local
      end

      config.add_config(:secondary) do |c|
        c.namespace = 'secondary_test_e2e'
        c.region = 'us-west-2'
        c.endpoint = 'http://localhost:8000' # DynamoDB Local
      end
    end
  end

  after do
    Dynamoid::MultiConfig.clear_all
  end

  let(:primary_model) do
    new_class(class_name: 'PrimaryModel') do
      include Dynamoid::Document

      dynamoid_config :primary

      field :name, :string
      field :value, :integer
    end
  end

  let(:secondary_model) do
    new_class(class_name: 'SecondaryModel') do
      include Dynamoid::Document

      dynamoid_config :secondary

      field :title, :string
      field :count, :integer
    end
  end

  it 'models use different adapters' do
    primary_adapter = primary_model.adapter
    secondary_adapter = secondary_model.adapter

    expect(primary_adapter).to be_a(Dynamoid::MultiConfigAdapter)
    expect(secondary_adapter).to be_a(Dynamoid::MultiConfigAdapter)
    expect(primary_adapter.object_id).not_to eq(secondary_adapter.object_id)
  end

  it 'models have correct table names with different namespaces' do
    # Test table names use correct namespaces
    expect(primary_model.table_name).to include('primary_test_e2e')
    expect(secondary_model.table_name).to include('secondary_test_e2e')

    # Ensure they use different namespaces
    expect(primary_model.table_name).not_to eq(secondary_model.table_name)
  end

  it 'models use correct configurations' do
    primary_config = Dynamoid::MultiConfig.get_config(:primary)
    secondary_config = Dynamoid::MultiConfig.get_config(:secondary)

    expect(primary_config.namespace).to eq('primary_test_e2e')
    expect(secondary_config.namespace).to eq('secondary_test_e2e')

    expect(primary_config.region).to eq('us-east-1')
    expect(secondary_config.region).to eq('us-west-2')
  end
end
