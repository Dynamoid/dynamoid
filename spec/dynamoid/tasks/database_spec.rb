require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Tasks::Database do

  describe '#ping' do
    context 'when the database is reachable' do
      it 'should be able to ping (connect to) DynamoDB' do
        expect( Dynamoid::Tasks::Database.ping ).to be_truthy
      end
    end
  end

  describe '#create_tables' do
    context 'when the tables don\'t already exist' do
      it 'should create tables' do
        expect(Dynamoid.adapter.list_tables).not_to include( *Dynamoid.included_models.map{ |m| m.table_name } )
        results = Dynamoid::Tasks::Database.create_tables
        expect(Dynamoid.adapter.list_tables).to include( *Dynamoid.included_models.map{ |m| m.table_name } )
        expect(results[:created]).to include( *Dynamoid.included_models.map{ |m| m.table_name } )
      end
    end
    context 'when the tables already exist' do
      it 'should not attempt to re-create the table' do
        Address.create_table
        expect(Dynamoid.adapter.list_tables).to include( Address.table_name )
        results = Dynamoid::Tasks::Database.create_tables
        expect(results[:existing]).to include( Address.table_name )
        expect(results[:created]).not_to include( Address.table_name )
      end
    end
  end

end
