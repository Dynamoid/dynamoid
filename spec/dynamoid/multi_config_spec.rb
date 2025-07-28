# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::MultiConfig do
  let(:primary_config) do
    {
      access_key: 'primary_access_key',
      secret_key: 'primary_secret_key',
      region: 'us-east-1',
      namespace: 'primary_test'
    }
  end

  let(:secondary_config) do
    {
      access_key: 'secondary_access_key',
      secret_key: 'secondary_secret_key',
      region: 'us-west-2',
      namespace: 'secondary_test'
    }
  end

  before do
    Dynamoid::MultiConfig.clear_all
  end

  after do
    Dynamoid::MultiConfig.clear_all
  end

  describe '.configure' do
    it 'allows configuration through a block' do
      Dynamoid::MultiConfig.configure do |config|
        config.add_config(:primary, primary_config)
        config.add_config(:secondary, secondary_config)
      end

      expect(Dynamoid::MultiConfig.configuration_names).to include(:primary, :secondary)
    end
  end

  describe '.add_config' do
    it 'adds a new configuration' do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)

      expect(Dynamoid::MultiConfig.configuration_exists?(:primary)).to be true
    end

    it 'allows configuration through a block' do
      Dynamoid::MultiConfig.add_config(:primary) do |config|
        config.access_key = 'test_key'
        config.secret_key = 'test_secret'
        config.region = 'us-east-1'
      end

      config = Dynamoid::MultiConfig.get_config(:primary)
      expect(config.access_key).to eq('test_key')
      expect(config.secret_key).to eq('test_secret')
      expect(config.region).to eq('us-east-1')
    end
  end

  describe '.get_config' do
    before do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
    end

    it 'returns the configuration for a given name' do
      config = Dynamoid::MultiConfig.get_config(:primary)
      expect(config.access_key).to eq('primary_access_key')
      expect(config.region).to eq('us-east-1')
    end

    it 'raises an error for unknown configuration' do
      expect { Dynamoid::MultiConfig.get_config(:unknown) }
        .to raise_error(Dynamoid::Errors::UnknownConfiguration)
    end
  end

  describe '.get_adapter' do
    before do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
    end

    it 'returns an adapter for the configuration' do
      adapter = Dynamoid::MultiConfig.get_adapter(:primary)
      expect(adapter).to be_a(Dynamoid::MultiConfigAdapter)
    end

    it 'raises an error for unknown configuration' do
      expect { Dynamoid::MultiConfig.get_adapter(:unknown) }
        .to raise_error(Dynamoid::Errors::UnknownConfiguration)
    end
  end

  describe '.configuration_names' do
    it 'returns all configuration names' do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
      Dynamoid::MultiConfig.add_config(:secondary, secondary_config)

      names = Dynamoid::MultiConfig.configuration_names
      expect(names).to contain_exactly(:primary, :secondary)
    end
  end

  describe '.configuration_exists?' do
    before do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
    end

    it 'returns true for existing configuration' do
      expect(Dynamoid::MultiConfig.configuration_exists?(:primary)).to be true
    end

    it 'returns false for non-existing configuration' do
      expect(Dynamoid::MultiConfig.configuration_exists?(:unknown)).to be false
    end
  end

  describe '.remove_config' do
    before do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
    end

    it 'removes a configuration' do
      Dynamoid::MultiConfig.remove_config(:primary)
      expect(Dynamoid::MultiConfig.configuration_exists?(:primary)).to be false
    end
  end

  describe '.clear_all' do
    before do
      Dynamoid::MultiConfig.add_config(:primary, primary_config)
      Dynamoid::MultiConfig.add_config(:secondary, secondary_config)
    end

    it 'removes all configurations' do
      Dynamoid::MultiConfig.clear_all
      expect(Dynamoid::MultiConfig.configuration_names).to be_empty
    end
  end
end
