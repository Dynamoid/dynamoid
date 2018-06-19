# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Tasks::Database do
  describe '#ping' do
    context 'when the database is reachable' do
      it 'should be able to ping (connect to) DynamoDB' do
        expect { Dynamoid::Tasks::Database.ping }.not_to raise_exception
      end
    end
  end

  describe '#create_tables' do
    before(:each) do
      Dynamoid.adapter.clear_cache!
      # depending on test execution order, Dynamoid.included_models gets polluted
      # so find everything that is capable of having a table_name
      @models = Dynamoid.included_models.reject { |m| m.base_class.try(:name).blank? }.uniq(&:table_name)
      # depending on test execution order, there are some tables hanging about
      # that are not in Dynamoid's table namespace and don't get auto cleaned.
      # We need this gone.
      existing_tables = @models.map(&:table_name) & Dynamoid.adapter.list_tables
      existing_tables.each { |t| Dynamoid.adapter.delete_table t }
    end

    context "when the tables don't already exist" do
      it 'should create tables' do
        expect(Dynamoid.adapter.list_tables).not_to include(*@models.map(&:table_name))
        results = Dynamoid::Tasks::Database.create_tables
        expect(Dynamoid.adapter.list_tables).to include(*@models.map(&:table_name))
        expect(results[:created]).to include(*@models.map(&:table_name))
      end
    end

    context 'when the tables already exist' do
      it 'should not attempt to re-create the table' do
        User.create_table
        expect(Dynamoid.adapter.list_tables).to include(User.table_name)
        results = Dynamoid::Tasks::Database.create_tables
        expect(results[:existing]).to include(User.table_name)
        expect(results[:created]).not_to include(User.table_name)
      end
    end
  end
end
