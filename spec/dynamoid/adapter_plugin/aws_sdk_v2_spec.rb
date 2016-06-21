require 'dynamoid/adapter_plugin/aws_sdk_v2'
require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper')

describe Dynamoid::AdapterPlugin::AwsSdkV2 do
  #
  # These let() definitions create tables "dynamoid_tests_TestTable<N>" and return the
  # name of the table.
  #
  # Name => Constructor args
  {
    1 => [:id],
    2 => [:id],
    3 => [:id, {:range_key => {:range => :number}}],
    4 => [:id, {:range_key => {:range => :number}}]
  }.each do |n, args|
    name = "dynamoid_tests_TestTable#{n}"
    let(:"test_table#{n}") do
      Dynamoid.adapter.create_table(name, *args)
      name
    end
  end

  #
  # Tests adapter against ranged tables
  #
  shared_examples 'range queries' do
    before do
      Dynamoid.adapter.put_item(test_table3, {:id => "1", :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => "1", :range => 3.0})
    end

    it 'performs query on a table with a range and selects items in a range' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_between => [0.0,3.0]).to_a).to eq [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items in a range with :select option' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_between => [0.0,3.0], :select =>  'ALL_ATTRIBUTES').to_a).to eq [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items greater than' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_greater_than => 1.0).to_a).to eq [{:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items less than' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_less_than => 2.0).to_a).to eq [{:id => '1', :range => BigDecimal.new(1)}]
    end

    it 'performs query on a table with a range and selects items gte' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_gte => 1.0).to_a).to eq [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items lte' do
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_lte => 3.0).to_a).to eq [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects all items' do
      200.times { |i| Dynamoid.adapter.put_item(test_table3, {:id => "1", :range => i.to_f, :data => "A"*1024*16}) }
      # 64 of these items will exceed the 1MB result limit thus query won't return all results on first loop
      expect(Dynamoid.adapter.query(test_table3, :hash_value => '1', :range_gte => 0.0).count).to eq(200)
    end
  end

  #
  # Tests scan_index_forwards flag behavior on range queries
  #
  shared_examples 'correct ordering' do
    before(:each) do
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 1, :range => 1.0})
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 2, :range => 2.0})
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 3, :range => 3.0})
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 4, :range => 4.0})
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 5, :range => 5.0})
      Dynamoid.adapter.put_item(test_table4, {:id => "1", :order => 6, :range => 6.0})
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
      query = Dynamoid.adapter.query(test_table4, :hash_value => '1', :range_greater_than => 0, :scan_index_forward => true).to_a
      expect(query[0]).to eq({:id => '1', :order => 1, :range => BigDecimal.new(1)})
      expect(query[1]).to eq({:id => '1', :order => 2, :range => BigDecimal.new(2)})
      expect(query[2]).to eq({:id => '1', :order => 3, :range => BigDecimal.new(3)})
      expect(query[3]).to eq({:id => '1', :order => 4, :range => BigDecimal.new(4)})
      expect(query[4]).to eq({:id => '1', :order => 5, :range => BigDecimal.new(5)})
      expect(query[5]).to eq({:id => '1', :order => 6, :range => BigDecimal.new(6)})
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
      query = Dynamoid.adapter.query(test_table4, :hash_value => '1', :range_greater_than => 0, :scan_index_forward => false).to_a
      expect(query[5]).to eq({:id => '1', :order => 1, :range => BigDecimal.new(1)})
      expect(query[4]).to eq({:id => '1', :order => 2, :range => BigDecimal.new(2)})
      expect(query[3]).to eq({:id => '1', :order => 3, :range => BigDecimal.new(3)})
      expect(query[2]).to eq({:id => '1', :order => 4, :range => BigDecimal.new(4)})
      expect(query[1]).to eq({:id => '1', :order => 5, :range => BigDecimal.new(5)})
      expect(query[0]).to eq({:id => '1', :order => 6, :range => BigDecimal.new(6)})
    end
  end


  context 'without a preexisting table' do
    # CreateTable and DeleteTable
    it 'performs CreateTable and DeleteTable' do
      table = Dynamoid.adapter.create_table('CreateTable', :id, :range_key =>  { :created_at => :number })

      expect(Dynamoid.adapter.list_tables).to include 'CreateTable'

      Dynamoid.adapter.delete_table('CreateTable')
    end

    describe 'create table with secondary index' do
      let(:doc_class) do
        Class.new do
          include Dynamoid::Document
          range :range => :number
          field :range2
          field :hash2
        end
      end

      it 'creates table with local_secondary_index' do
        # setup
        doc_class.table({:name => 'table_lsi', :key => :id})
        doc_class.local_secondary_index ({
          :range_key => :range2,
        })

        Dynamoid.adapter.create_table('table_lsi', :id, {
          :local_secondary_indexes => doc_class.local_secondary_indexes.values,
          :range_key => { :range => :number }
        })

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_lsi')
        data = resp.data
        lsi = data.table.local_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV2::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV2::TABLE_STATUSES[:active])
        expect(lsi.index_name).to eql "dynamoid_tests_table_lsi_index_id_range2"
        expect(lsi.key_schema.map(&:to_hash)).to eql [
          {:attribute_name=>"id", :key_type=>"HASH"},
          {:attribute_name=>"range2", :key_type=>"RANGE"}
        ]
        expect(lsi.projection.to_hash).to eql ({:projection_type=>"KEYS_ONLY"})
      end

      it 'creates table with global_secondary_index' do
        # setup
        doc_class.table({:name => 'table_gsi', :key => :id})
        doc_class.global_secondary_index ({
          :hash_key => :hash2,
          :range_key => :range2,
          :write_capacity => 10,
          :read_capacity => 20

        })
        Dynamoid.adapter.create_table('table_gsi', :id, {
          :global_secondary_indexes => doc_class.global_secondary_indexes.values,
          :range_key => { :range => :number }
        })

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_gsi')
        data = resp.data
        gsi = data.table.global_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV2::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV2::TABLE_STATUSES[:active])
        expect(gsi.index_name).to eql "dynamoid_tests_table_gsi_index_hash2_range2"
        expect(gsi.key_schema.map(&:to_hash)).to eql [
          {:attribute_name=>"hash2", :key_type=>"HASH"},
          {:attribute_name=>"range2", :key_type=>"RANGE"}
        ]
        expect(gsi.projection.to_hash).to eql ({:projection_type=>"KEYS_ONLY"})
        expect(gsi.provisioned_throughput.write_capacity_units).to eql 10
        expect(gsi.provisioned_throughput.read_capacity_units).to eql 20
      end
    end
  end


  context 'with a preexisting table' do
    # GetItem, PutItem and DeleteItem
    it "performs GetItem for an item that does not exist" do
      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it "performs GetItem for an item that does exist" do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq({:name => 'Josh', :id => '1'})

      Dynamoid.adapter.delete_item(test_table1, '1')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'performs GetItem for an item that does exist with a range key' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 2.0})

      expect(Dynamoid.adapter.get_item(test_table3, '1', :range_key => 2.0)).to eq({:name => 'Josh', :id => '1', :range => 2.0})

      Dynamoid.adapter.delete_item(test_table3, '1', :range_key => 2.0)

      expect(Dynamoid.adapter.get_item(test_table3, '1', :range_key => 2.0)).to be_nil
    end

    it 'performs DeleteItem for an item that does not exist' do
      Dynamoid.adapter.delete_item(test_table1, '1')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'performs PutItem for an item that does not exist' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq({:id => '1', :name => 'Josh'})
    end

    # BatchGetItem
    it 'passes options to underlying BatchGet call' do
      pending "at the moment passing the options to underlying batch get is not supported"
      expect_any_instance_of(Aws::DynamoDB::Client).to receive(:batch_get_item).with(:request_items => {test_table1 => {:keys => [{'id' => '1'}, {'id' => '2'}], :consistent_read => true}}).and_call_original
      described_class.batch_get_item({test_table1 => ['1', '2']}, :consistent_read => true)
    end

    it "performs BatchGetItem with singular keys" do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table2, {:id => '1', :name => 'Justin'})

      results = Dynamoid.adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      expect(results.size).to eq 2
      expect(results[test_table1]).to include({:name => 'Josh', :id => '1'})
      expect(results[test_table2]).to include({:name => 'Justin', :id => '1'})
    end

    it "performs BatchGetItem with multiple keys" do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      results = Dynamoid.adapter.batch_get_item(test_table1 => ['1', '2'])
      expect(results.size).to eq 1
      expect(results[test_table1]).to include({:name => 'Josh', :id => '1'})
      expect(results[test_table1]).to include({:name => 'Justin', :id => '2'})
    end

    it 'performs BatchGetItem with one ranged key' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0]])
      expect(results.size).to eq 1
      expect(results[test_table3]).to include({:name => 'Josh', :id => '1', :range => 1.0})
    end

    it 'performs BatchGetItem with multiple ranged keys' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0],['2', 2.0]])
      expect(results.size).to eq 1

      expect(results[test_table3]).to include({:name => 'Josh', :id => '1', :range => 1.0})
      expect(results[test_table3]).to include({:name => 'Justin', :id => '2', :range => 2.0})
    end

    it 'performs BatchGetItem with ranges of 100 keys' do
      table_ids = []

      (1..101).each do |i|
        id, range = i.to_s, i.to_f
        Dynamoid.adapter.put_item(test_table3, {:id => id, :name => "Josh_#{i}", :range => range})
        table_ids << [id, range]
      end

      results = Dynamoid.adapter.batch_get_item(test_table3 => table_ids)

      expect(results.size).to eq 1

      expect(results[test_table3]).to include({:name => 'Josh_101', :id => '101', :range => 101.0})
    end

    # BatchDeleteItem
    it "performs BatchDeleteItem with singular keys" do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table2, {:id => '1', :name => 'Justin'})

      Dynamoid.adapter.batch_delete_item(test_table1 => ['1'], test_table2 => ['1'])

      results = Dynamoid.adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      expect(results.size).to eq 2

      expect(results[test_table1]).to be_blank
      expect(results[test_table2]).to be_blank
    end

    it "performs BatchDeleteItem with multiple keys" do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      Dynamoid.adapter.batch_delete_item(test_table1 => ['1', '2'])

      results = Dynamoid.adapter.batch_get_item(test_table1 => ['1', '2'])

      expect(results.size).to eq 1
      expect(results[test_table1]).to be_blank
    end

    it 'performs BatchDeleteItem with one ranged key' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      Dynamoid.adapter.batch_delete_item(test_table3 => [['1', 1.0]])
      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0]])

      expect(results.size).to eq 1
      expect(results[test_table3]).to be_blank
    end

    it 'performs BatchDeleteItem with multiple ranged keys' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      Dynamoid.adapter.batch_delete_item(test_table3 => [['1', 1.0],['2', 2.0]])
      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0],['2', 2.0]])

      expect(results.size).to eq 1
      expect(results[test_table3]).to be_blank
    end

    # ListTables
    it 'performs ListTables' do
      #Force creation of the tables
      test_table1; test_table2; test_table3; test_table4

      expect(Dynamoid.adapter.list_tables).to include test_table1
      expect(Dynamoid.adapter.list_tables).to include test_table2
    end

    # Query
    it 'performs query on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      expect(Dynamoid.adapter.query(test_table1, :hash_value => '1').first).to eq({ :id=> '1', :name=>"Josh" })
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      expect(Dynamoid.adapter.query(test_table1, :hash_value => '1').first).to eq({ :id=> '1', :name=>"Josh" })
    end

    it_behaves_like 'range queries'

    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      expect(Dynamoid.adapter.scan(test_table1, :name => 'Josh').to_a).to eq [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      expect(Dynamoid.adapter.scan(test_table1, :name => 'Josh').to_a).to eq [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Josh'})

      expect(Dynamoid.adapter.scan(test_table1, :name => 'Josh')).to include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end

    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Josh'})

      expect(Dynamoid.adapter.scan(test_table1, {})).to include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end

    # Truncate
    it 'performs truncate on an existing table' do
      Dynamoid.adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid.adapter.put_item(test_table1, {:id => '2', :name => 'Pascal'})

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq({:name => 'Josh', :id => '1'})
      expect(Dynamoid.adapter.get_item(test_table1, '2')).to eq({:name => 'Pascal', :id => '2'})

      Dynamoid.adapter.truncate(test_table1)

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
      expect(Dynamoid.adapter.get_item(test_table1, '2')).to be_nil
    end

    it 'performs truncate on an existing table with a range key' do
      Dynamoid.adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid.adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      Dynamoid.adapter.truncate(test_table3)

      expect(Dynamoid.adapter.get_item(test_table3, '1', :range_key => 1.0)).to be_nil
      expect(Dynamoid.adapter.get_item(test_table3, '2', :range_key => 2.0)).to be_nil
    end

    it_behaves_like 'correct ordering'
  end

  # DescribeTable

  # UpdateItem

  # UpdateTable
end
