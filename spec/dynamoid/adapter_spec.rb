require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Adapter do
  subject { described_class.new }

  def test_table; 'dynamoid_tests_TestTable'; end
  let(:single_id){'123'}
  let(:many_ids){%w(1 2)}

  describe 'connection management' do
    it 'does not auto-establish a connection' do
      expect_any_instance_of(described_class.adapter_plugin_class).to_not receive(:connect!)
      subject
    end

    it 'establishes a connection when adapter is requested' do
      expect_any_instance_of(described_class.adapter_plugin_class).to receive(:connect!).and_call_original
      subject.adapter
    end

    it 'reuses a connection' do
      expect_any_instance_of(described_class.adapter_plugin_class).to receive(:connect!).once.and_call_original
      subject.adapter
      subject.adapter
    end
  end

  describe 'caching tables' do
    it 'caches list of tables' do
      expect(subject).to receive(:list_tables).once.and_call_original
      subject.create_table('test_table', 'key')
      subject.tables
      subject.tables
    end

    it 'maintains table cache when creating a table' do
      # cache
      subject.tables

      expect(subject).to_not receive(:list_tables)
      subject.create_table('test_table', 'key')
      expect(subject.tables).to include('test_table')
    end

    it 'clears cached list via #clear_cache!' do
      subject.create_table('test_table', 'key')
      subject.clear_cache!
      expect(subject).to receive(:list_tables).and_call_original
      subject.tables
    end
  end

  it 'raises NoMethodError if we try a method that is not on the child' do
    expect {subject.foobar}.to raise_error(NoMethodError)
  end

  it 'writes through the adapter' do
    expect(subject).to receive(:put_item).with(test_table, {:id => single_id}, nil).and_return(true)
    subject.write(test_table, {:id => single_id})
  end

  it 'reads through the adapter for one ID' do
    expect(subject).to receive(:get_item).with(test_table, single_id, {}).and_return(true)
    subject.read(test_table, single_id)
  end

  it 'reads through the adapter for many IDs' do
    expect(subject).to receive(:batch_get_item).with({test_table => many_ids}, {}).and_return(true)
    subject.read(test_table, many_ids)
  end

  it 'delete through the adapter for one ID' do
    expect(subject).to receive(:delete_item).with(test_table, single_id, {}).and_return(nil)
    subject.delete(test_table, single_id)
  end

  it 'deletes through the adapter for many IDs' do
    expect(subject).to receive(:batch_delete_item).with({test_table => many_ids}).and_return(nil)
    subject.delete(test_table, many_ids)
  end

  it 'reads through the adapter for one ID and a range key' do
    expect(subject).to receive(:get_item).with(test_table, single_id, :range_key => 2.0).and_return(true)
    subject.read(test_table, single_id, :range_key => 2.0)
  end

  it 'reads through the adapter for many IDs and a range key' do
    expect(subject).to receive(:batch_get_item).with({test_table => [['1', 2.0], ['2', 2.0]]}, {}).and_return(true)
    subject.read(test_table, many_ids, :range_key => 2.0)
  end

  it 'deletes through the adapter for one ID and a range key' do
    expect(subject).to receive(:delete_item).with(test_table, single_id, :range_key => 2.0).and_return(nil)
    subject.delete(test_table, single_id, :range_key => 2.0)
  end

  it 'deletes through the adapter for many IDs and a range key' do
    expect(subject).to receive(:batch_delete_item).with({test_table => [['1', 2.0], ['2', 2.0]]}).and_return(nil)
    subject.delete(test_table, many_ids, :range_key => [2.0,2.0])
  end
end
