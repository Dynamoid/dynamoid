# frozen_string_literal: true

require 'spec_helper'

describe 'Multi-config Document Integration' do
  let(:primary_config) do
    {
      namespace: 'primary_test',
      region: 'us-east-1'
    }
  end

  let(:secondary_config) do
    {
      namespace: 'secondary_test',
      region: 'us-west-2'
    }
  end

  before do
    Dynamoid::MultiConfig.clear_all

    Dynamoid::MultiConfig.configure do |config|
      config.add_config(:primary, primary_config)
      config.add_config(:secondary, secondary_config)
    end
  end

  after do
    Dynamoid::MultiConfig.clear_all
  end

  describe 'model with multi-config' do
    let(:primary_user_class) do
      new_class(class_name: 'PrimaryUser') do
        include Dynamoid::Document

        dynamoid_config :primary

        field :name, :string
        field :email, :string
      end
    end

    let(:secondary_user_class) do
      new_class(class_name: 'SecondaryUser') do
        include Dynamoid::Document

        dynamoid_config :secondary

        field :name, :string
        field :age, :integer
      end
    end

    let(:default_user_class) do
      new_class(class_name: 'DefaultUser') do
        include Dynamoid::Document

        field :name, :string
        field :username, :string
      end
    end

    it 'uses correct configuration for primary model' do
      expect(primary_user_class.dynamoid_config_name).to eq(:primary)
      expect(primary_user_class.adapter).to be_a(Dynamoid::MultiConfigAdapter)
    end

    it 'uses correct configuration for secondary model' do
      expect(secondary_user_class.dynamoid_config_name).to eq(:secondary)
      expect(secondary_user_class.adapter).to be_a(Dynamoid::MultiConfigAdapter)
    end

    it 'uses default adapter for model without config' do
      expect(default_user_class.dynamoid_config_name).to be_nil
      expect(default_user_class.adapter).to eq(Dynamoid.adapter)
    end

    it 'generates correct table names with different namespaces' do
      expect(primary_user_class.table_name).to start_with('primary_test_')
      expect(secondary_user_class.table_name).to start_with('secondary_test_')
      expect(default_user_class.table_name).to start_with(Dynamoid::Config.namespace.to_s)
    end

    it 'each model uses its own adapter for operations' do
      allow(Dynamoid::MultiConfig).to receive(:get_adapter).with(:primary).and_call_original
      allow(Dynamoid::MultiConfig).to receive(:get_adapter).with(:secondary).and_call_original

      primary_adapter = primary_user_class.adapter
      secondary_adapter = secondary_user_class.adapter

      expect(primary_adapter).not_to eq(secondary_adapter)

      # Test that each model uses its own adapter
      expect(primary_adapter).to receive(:count).with(primary_user_class.table_name)
      primary_user_class.count

      expect(secondary_adapter).to receive(:count).with(secondary_user_class.table_name)
      secondary_user_class.count
    end
  end

  describe 'error handling' do
    let(:invalid_config_class) do
      new_class(class_name: 'InvalidConfigUser') do
        include Dynamoid::Document

        dynamoid_config :nonexistent

        field :name, :string
      end
    end

    it 'raises error when using unknown configuration' do
      expect { invalid_config_class.adapter }
        .to raise_error(Dynamoid::Errors::UnknownConfiguration, /nonexistent/)
    end
  end
end
