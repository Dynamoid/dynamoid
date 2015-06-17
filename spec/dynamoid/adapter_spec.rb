require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Adapter do
  
  def test_table; 'dynamoid_tests_TestTable'; end
  let(:single_id){'123'}
  let(:many_ids){%w(1 2)}

  before(:all) do
    described_class.create_table(test_table, :id) unless described_class.list_tables.include?(test_table)
  end
  
  it 'extends itself automatically' do
    expect {described_class.list_tables}.to_not raise_error
  end

  it 'raises NoMethodError if we try a method that is not on the child' do
    expect {described_class.foobar}.to raise_error(NoMethodError)
  end
  
  context 'without partioning' do
    before(:all) do
      @previous_value = Dynamoid::Config.partitioning
      Dynamoid::Config.partitioning = false
    end
    
    after(:all) do
      Dynamoid::Config.partitioning = @previous_value
    end
    
    it 'writes through the adapter' do
      expect(described_class).to receive(:put_item).with(test_table, {:id => single_id}, nil).and_return(true)
      described_class.write(test_table, {:id => single_id})
    end

    it 'reads through the adapter for one ID' do
      expect(described_class).to receive(:get_item).with(test_table, single_id, {}).and_return(true)
      described_class.read(test_table, single_id)
    end

    it 'reads through the adapter for many IDs' do
      expect(described_class).to receive(:batch_get_item).with({test_table => many_ids}, {}).and_return(true)
      described_class.read(test_table, many_ids)
    end

    it 'delete through the adapter for one ID' do
      expect(described_class).to receive(:delete_item).with(test_table, single_id, {}).and_return(nil)
      described_class.delete(test_table, single_id)
    end

    it 'deletes through the adapter for many IDs' do
      expect(described_class).to receive(:batch_delete_item).with({test_table => many_ids}).and_return(nil)
      described_class.delete(test_table, many_ids)
    end

    it 'reads through the adapter for one ID and a range key' do
      expect(described_class).to receive(:get_item).with(test_table, single_id, :range_key => 2.0).and_return(true)
      described_class.read(test_table, single_id, :range_key => 2.0)
    end

    it 'reads through the adapter for many IDs and a range key' do
      expect(described_class).to receive(:batch_get_item).with({test_table => [['1', 2.0], ['2', 2.0]]}, {}).and_return(true)
      described_class.read(test_table, many_ids, :range_key => 2.0)
    end

    it 'deletes through the adapter for one ID and a range key' do
      expect(described_class).to receive(:delete_item).with(test_table, single_id, :range_key => 2.0).and_return(nil)
      described_class.delete(test_table, single_id, :range_key => 2.0)
    end

    it 'deletes through the adapter for many IDs and a range key' do
      expect(described_class).to receive(:batch_delete_item).with({test_table => [['1', 2.0], ['2', 2.0]]}).and_return(nil)
      described_class.delete(test_table, many_ids, :range_key => [2.0,2.0])
    end
  end

  # TODO: Partitioning specs when partition is working
end
