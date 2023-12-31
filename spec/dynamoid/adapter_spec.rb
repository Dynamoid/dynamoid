# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Adapter do
  subject { described_class.new }

  def test_table
    'dynamoid_tests_TestTable'
  end
  let(:single_id) { '123' }
  let(:many_ids) { %w[1 2] }

  {
    1 => [:id],
    2 => [:id],
    3 => [:id, { range_key: { range: :number } }],
    4 => [:id, { range_key: { range: :number } }]
  }.each do |n, args|
    name = "dynamoid_tests_TestTable#{n}"
    let(:"test_table#{n}") do
      Dynamoid.adapter.create_table(name, *args)
      name
    end
  end

  describe 'connection management' do
    it 'does not auto-establish a connection' do
      expect_any_instance_of(described_class.adapter_plugin_class).not_to receive(:connect!)
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

      expect(subject).not_to receive(:list_tables)
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
    expect { subject.foobar }.to raise_error(NoMethodError)
  end

  it 'writes through the adapter' do
    expect(subject).to receive(:put_item).with(test_table, { id: single_id }, nil).and_return(true)
    subject.write(test_table, id: single_id)
  end

  describe '#read' do
    it 'reads through the adapter for one ID' do
      expect(subject).to receive(:get_item).with(test_table, single_id, {}).and_return(true)
      subject.read(test_table, single_id)
    end

    it 'reads through the adapter for many IDs' do
      expect(subject).to receive(:batch_get_item).with({ test_table => many_ids }, {}).and_return(true)
      subject.read(test_table, many_ids)
    end

    it 'reads through the adapter for one ID and a range key' do
      allow(subject).to receive(:get_item).and_return(true)
      subject.read(test_table, single_id, range_key: 'boot')
      expect(subject).to have_received(:get_item).with(test_table, single_id, { range_key: 'boot' })
    end
  end

  describe '#create_table' do
    let(:table_name) { "#{Dynamoid::Config.namespace}_create_table_test" }

    after do
      Dynamoid.adapter.delete_table(table_name)
    end

    it 'does not try to create table if it is already in cache' do
      expect(Dynamoid.adapter.client).to receive(:create_table).once
        .and_call_original

      3.times { Dynamoid.adapter.create_table(table_name, :id, sync: true) }
    end

    it 'returns true if table created' do
      actual = Dynamoid.adapter.create_table(table_name, :id, sync: true)
      expect(actual).to be true
    end

    it 'returns false if table was created earlier' do
      Dynamoid.adapter.create_table(table_name, :id, sync: true)

      actual = Dynamoid.adapter.create_table(table_name, :id, sync: true)
      expect(actual).to be false
    end
  end

  describe '#delete' do
    it 'deletes through the adapter for one ID' do
      Dynamoid.adapter.put_item(test_table1, id: '1')
      Dynamoid.adapter.put_item(test_table1, id: '2')

      expect do
        subject.delete(test_table1, '1')
      end.to change {
        Dynamoid.adapter.scan(test_table1).flat_map { |i| i }.to_a.size
      }.from(2).to(1)

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'deletes through the adapter for many IDs' do
      Dynamoid.adapter.put_item(test_table1, id: '1')
      Dynamoid.adapter.put_item(test_table1, id: '2')
      Dynamoid.adapter.put_item(test_table1, id: '3')

      expect do
        subject.delete(test_table1, %w[1 2])
      end.to change {
        Dynamoid.adapter.scan(test_table1).flat_map { |i| i }.to_a.size
      }.from(3).to(1)

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
      expect(Dynamoid.adapter.get_item(test_table1, '2')).to be_nil
    end

    it 'deletes through the adapter for one ID and a range key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', range: 2.0)

      expect do
        subject.delete(test_table3, '1', range_key: 1.0)
      end.to change {
        Dynamoid.adapter.scan(test_table3).flat_map { |i| i }.to_a.size
      }.from(2).to(1)

      expect(Dynamoid.adapter.get_item(test_table3, '1', range_key: 1.0)).to be_nil
    end

    it 'deletes through the adapter for many IDs and a range key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '1', range: 2.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', range: 2.0)

      expect(subject).to receive(:batch_delete_item).and_call_original

      expect do
        subject.delete(test_table3, %w[1 2], range_key: 1.0)
      end.to change {
        Dynamoid.adapter.scan(test_table3).flat_map { |i| i }.to_a.size
      }.from(4).to(2)

      expect(Dynamoid.adapter.get_item(test_table3, '1', range_key: 1.0)).to be_nil
      expect(Dynamoid.adapter.get_item(test_table3, '2', range_key: 1.0)).to be_nil
    end
  end
end
