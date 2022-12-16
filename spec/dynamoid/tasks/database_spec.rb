# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Tasks::Database do
  describe '#ping' do
    context 'when the database is reachable' do
      it 'is able to ping (connect to) DynamoDB' do
        expect { described_class.ping }.not_to raise_exception
      end
    end
  end

  describe '#create_tables' do
    before do
      @klass = new_class
    end

    context "when the tables don't exist yet" do
      it 'creates tables' do
        expect {
          described_class.create_tables
        }.to change {
          Dynamoid.adapter.list_tables.include?(@klass.table_name)
        }.from(false).to(true)
      end

      it 'returns created table names' do
        results = described_class.create_tables
        expect(results[:existing]).not_to include(@klass.table_name)
        expect(results[:created]).to include(@klass.table_name)
      end
    end

    context 'when the tables already exist' do
      it 'does not attempt to re-create the table' do
        @klass.create_table

        results = described_class.create_tables
        expect(results[:existing]).to include(@klass.table_name)
        expect(results[:created]).not_to include(@klass.table_name)
      end
    end
  end
end
