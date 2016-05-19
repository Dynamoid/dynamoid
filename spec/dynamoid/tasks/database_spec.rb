require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Tasks::Database do
  context 'when the database is reachable' do
    it 'should be able to ping (connect to) DynamoDB' do
      expect( Dynamoid::Tasks::Database.ping ).to be_truthy
    end
  end

end
