# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TestHelper do
  describe '.create_tables' do
    let(:klass) { new_class }

    it 'creates tables for specified models' do
      expect {
        described_class.create_tables(klass)
      }.to change {
        Dynamoid.adapter.list_tables.include?(klass.table_name)
      }.from(false).to(true)
    end

    it 'creates tables for all included models when no models are specified', config: { models_dir: MODELS } do
      allow(Dynamoid).to receive(:included_models).and_return([klass])

      expect {
        described_class.create_tables
      }.to change {
        Dynamoid.adapter.list_tables.include?(klass.table_name)
      }.from(false).to(true)
    end

    it 'creates tables when models_dir is nil', config: { models_dir: nil } do
      allow(Dynamoid).to receive(:included_models).and_return([klass])

      expect {
        described_class.create_tables
      }.to change {
        Dynamoid.adapter.list_tables.include?(klass.table_name)
      }.from(false).to(true)
    end

    it 'raises error if models_dir does not exist', config: { models_dir: './non_existent_models_dir' } do
      expect {
        described_class.create_tables
      }.to raise_error(Dynamoid::Errors::Error, /models_dir.*does not exist/)
    end
  end

  describe '.truncate_tables' do
    let(:klass) { new_class }

    it 'clears all records from the table for specified models' do
      klass.create(name: 'test 1')
      klass.create(name: 'test 2')
      expect(klass.all.count).to eq(2)

      described_class.truncate_tables(klass)

      expect(klass.all.count).to eq(0)
    end

    it 'clears all records for all included models when no arguments are specified' do
      allow(Dynamoid).to receive(:included_models).and_return([klass])
      klass.create(name: 'test 1')
      expect(klass.all.count).to eq(1)

      described_class.truncate_tables

      expect(klass.all.count).to eq(0)
    end
  end

  describe '.drop_tables' do
    let(:klass) { new_class }

    it 'drops tables matching namespace' do
      klass.create_table
      expect(Dynamoid.adapter.list_tables).to include(klass.table_name)

      described_class.drop_tables

      expect(Dynamoid.adapter.list_tables).not_to include(klass.table_name)
    end

    it 'does not drop tables from other namespaces' do
      klass.create_table
      table_name = klass.table_name
      allow(Dynamoid.config).to receive(:namespace).and_return('other_namespace')

      expect {
        described_class.drop_tables
      }.not_to change {
        Dynamoid.adapter.list_tables.include?(table_name)
      }.from(true)
    end

    it 'raises error if namespace is empty', config: { namespace: nil } do
      expect {
        described_class.drop_tables
      }.to raise_error(Dynamoid::Errors::Error, /namespace must be set/)
    end
  end
end
