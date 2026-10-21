# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe 'delete_table' do
    it 'deletes the table' do
      klass = new_class
      klass.create_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq true

      klass.delete_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq false
    end

    it 'returns self' do
      klass = new_class
      klass.create_table

      result = klass.delete_table

      expect(result).to eq klass
    end

    it 'passes options to adapter' do
      klass = new_class
      expect(Dynamoid.adapter).to receive(:delete_table).with(klass.table_name, sync: true)

      klass.delete_table(sync: true)
    end
  end
end
