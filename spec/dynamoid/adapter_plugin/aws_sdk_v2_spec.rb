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
    3 => [:id, {range_key: {range: :number}}],
    4 => [:id, {range_key: {range: :number}}]
  }.each do |n, args|
    name = "dynamoid_tests_TestTable#{n}"
    let(:"test_table#{n}") do
      Dynamoid.adapter.create_table(name, *args)
      name
    end
  end

  #
  # Test limit controls in querys and scans
  #
  # Since query and scans have different interface, then including this shared example
  # requires some inputs. The internal aspects will configure request parameters and
  # the Dynamoid adapter call correctly.
  #
  # @param [Symbol] request_type the name of the request, either :query or :scan
  #
  shared_examples 'correctly handling limits' do |request_type|
    before(:each) do
      @request_type = request_type
    end

    def request_params
      return {hash_value: '1'} if @request_type == :query
      {}
    end

    def dynamo_request(table_name, scan_hash = {}, select_opts = {})
      return Dynamoid.adapter.query(table_name, scan_hash.merge(select_opts)) if @request_type == :query
      Dynamoid.adapter.scan(table_name, scan_hash, select_opts)
    end

    context 'multiple name entities' do
      before(:each) do
        (1..4).each do |i|
          Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: i.to_f)
          Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Pascal', range: (i + 4).to_f)
        end
      end

      it 'returns correct records' do
        expect(dynamo_request(test_table3, request_params, {}).count).to eq(8)
      end

      it 'returns correct record limit' do
        expect(dynamo_request(test_table3, request_params, record_limit: 1).count).to eq(1)
        expect(dynamo_request(test_table3, request_params, record_limit: 3).count).to eq(3)
      end

      it 'returns correct batch' do
        # Receives 8 times for each item and 1 more for empty page
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(9).times.and_call_original
        expect(dynamo_request(test_table3, request_params, batch_size: 1).count).to eq(8)
      end

      it 'returns correct batch and paginates in batches' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(3).times.and_call_original
        expect(dynamo_request(test_table3, request_params, batch_size: 3).count).to eq(8)
      end

      it 'returns correct record limit and batch' do
        expect(dynamo_request(test_table3, request_params, record_limit: 1, batch_size: 1).count).to eq(1)
      end

      it 'returns correct record limit with filter' do
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Josh'}), record_limit: 1).count)
          .to eq(1)
      end

      it 'obeys correct scan limit with filter' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(1).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Josh'}), scan_limit: 2).count)
          .to eq(2)
      end

      it 'obeys correct scan limit over record limit with filter' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(1).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Josh'}),
          scan_limit: 2,
          record_limit: 10, # Won't be able to return more than 2 due to scan limit
        ).count).to eq(2)
      end

      it 'obeys correct scan limit with filter with some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(1).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Pascal'}),
          scan_limit: 5
        ).count).to eq(1)
      end

      it 'obeys correct scan limit and batch size with filter with some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(2).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Josh'}),
          scan_limit: 3,
          batch_size: 2, # This would force batching of size 2 for potential of 4 results!
        ).count).to eq(3)
      end

      it 'obeys correct scan limit with filter and batching for some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(5).times.and_call_original
        # We should paginate through 5 responses each of size 1 (batch) and
        # only scan through 5 records at most which with our given filter
        # should return 1 result since first 4 are Josh and last is Pascal.
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Pascal'}),
          batch_size: 1,
          scan_limit: 5,
          record_limit: 3
        ).count).to eq(1)
      end

      it 'obeys correct record limit with filter, batching, and scan limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(6).times.and_call_original
        # We should paginate through 6 responses each of size 1 (batch) and
        # only scan through 6 records at most which with our given filter
        # should return 2 results, and hit record limit before scan limit.
        expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Pascal'}),
          batch_size: 1,
          scan_limit: 10,
          record_limit: 2
        ).count).to eq(2)
      end
    end

    #
    # Tests that even with large records we are paginating to pull more data
    # even if we hit response data size limits
    #
    context 'large records still returns as much data' do
      before(:each) do
        # 64 of these items will exceed the 1MB result record_limit thus query won't return all results on first loop
        # We use :age since :range won't work for filtering in queries
        200.times do |i|
          Dynamoid.adapter.put_item(test_table3,
            id: '1',
            range: i.to_f,
            age: i.to_f,
            data: 'A'*1024*16)
        end
      end

      it 'returns correct for limits and scan limit' do
        expect(dynamo_request(test_table3, request_params,
          scan_limit: 100
        ).count).to eq(100)
      end

      it 'returns correct for scan limit with filtering' do
        # Not sure why there is difference but :query will do 1 page and see 100 records and filter out 10
        # while :scan will do 2 pages and see 64 records on first page similar to the 1MB return limit
        # and then look at 36 records and find 10 on the second page.
        pages = request_type == :query ? 1 : 2
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(pages).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(age: {gte: 90.0}),
          scan_limit: 100
        ).count).to eq(10)
      end

      it 'returns correct for record limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(2).times.and_call_original
        expect(dynamo_request(test_table3, request_params.merge(age: {gte: 5.0}),
          record_limit: 100
        ).count).to eq(100)
      end

      it 'returns correct record limit with filtering' do
        expect(dynamo_request(test_table3, request_params.merge(age: {gte: 133.0}),
          record_limit: 100
        ).count).to eq(67)
      end

      it 'returns correct with batching' do
        # Since we hit the data size limit 3 times, so we must make 4 requests
        # which is limitation of DynamoDB and therefore batch limit is
        # restricted by this limitation as well!
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(4).times.and_call_original
        expect(dynamo_request(test_table3, request_params,
          batch_size: 100
        ).count).to eq(200)
      end

      it 'returns correct with batching and record limit beyond data size limit' do
        # Since we hit limit once, we need to make sure the second request only
        # requests for as many as we have left for our record limit.
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(2).times.and_call_original
        expect(dynamo_request(test_table3, request_params,
          record_limit: 83,
          batch_size: 100
        ).count).to eq(83)
      end

      it 'returns correct with batching and record limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(11).times.and_call_original
        # Since we do age >= 5.0 we lose the first 5 results so we make 11 paginated requests
        expect(dynamo_request(test_table3, request_params.merge(age: {gte: 5.0}),
          record_limit: 100,
          batch_size: 10
        ).count).to eq(100)
      end
    end

    it 'correctly limits edge case of record and scan counts approaching limits' do
      (1..4).each do |i|
        Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: i.to_f)
      end
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Pascal', range: 5.0)
      (6..10).each do |i|
        Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: i.to_f)
      end

      expect(Dynamoid.adapter.client).to receive(request_type).exactly(2).times.and_call_original
      # In faulty code, the record limit would adjust limit to 2 thus on second page
      # we would get the 5th Josh (range value 6.0) whereas correct implementation would
      # adjust limit to 1 since can only scan 1 more record therefore would see Pascal
      # and not go to next valid record.
      expect(dynamo_request(test_table3, request_params.merge(name: {eq: 'Josh'}),
        batch_size: 4,
        scan_limit: 5,    # Scan limit would adjust requested limit to 1
        record_limit: 6,  # Record limit would adjust requested limit to 2
      ).count).to eq(4)
    end
  end

  #
  # Tests adapter against ranged tables
  #
  shared_examples 'range queries' do
    before do
      Dynamoid.adapter.put_item(test_table3, id: '1', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '1', range: 3.0)
    end

    it 'performs query on a table with a range and selects items in a range' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_between: [0.0, 3.0]).to_a).to eq [{id: '1', range: BigDecimal.new(1)}, {id: '1', range: BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items in a range with :select option' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_between: [0.0, 3.0], select: 'ALL_ATTRIBUTES').to_a).to eq [{id: '1', range: BigDecimal.new(1)}, {id: '1', range: BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items greater than' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_greater_than: 1.0).to_a).to eq [{id: '1', range: BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items less than' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_less_than: 2.0).to_a).to eq [{id: '1', range: BigDecimal.new(1)}]
    end

    it 'performs query on a table with a range and selects items gte' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_gte: 1.0).to_a).to eq [{id: '1', range: BigDecimal.new(1)}, {id: '1', range: BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items lte' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_lte: 3.0).to_a).to eq [{id: '1', range: BigDecimal.new(1)}, {id: '1', range: BigDecimal.new(3)}]
    end

    it 'performs query on a table and returns items based on returns correct limit' do
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_greater_than: 0.0, record_limit: 1).count).to eq(1)
    end

    it 'performs query on a table with a range and selects all items' do
      200.times { |i| Dynamoid.adapter.put_item(test_table3, id: '1', range: i.to_f, data: 'A'*1024*16) }
      # 64 of these items will exceed the 1MB result limit thus query won't return all results on first loop
      expect(Dynamoid.adapter.query(test_table3, hash_value: '1', range_gte: 0.0).count).to eq(200)
    end
  end

  #
  # Tests scan_index_forwards flag behavior on range queries
  #
  shared_examples 'correct ordering' do
    before(:each) do
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 1, range: 1.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 2, range: 2.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 3, range: 3.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 4, range: 4.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 5, range: 5.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 6, range: 6.0)
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
      query = Dynamoid.adapter.query(test_table4, hash_value: '1', range_greater_than: 0, scan_index_forward: true).to_a
      expect(query[0]).to eq(id: '1', order: 1, range: BigDecimal.new(1))
      expect(query[1]).to eq(id: '1', order: 2, range: BigDecimal.new(2))
      expect(query[2]).to eq(id: '1', order: 3, range: BigDecimal.new(3))
      expect(query[3]).to eq(id: '1', order: 4, range: BigDecimal.new(4))
      expect(query[4]).to eq(id: '1', order: 5, range: BigDecimal.new(5))
      expect(query[5]).to eq(id: '1', order: 6, range: BigDecimal.new(6))
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
      query = Dynamoid.adapter.query(test_table4, hash_value: '1', range_greater_than: 0, scan_index_forward: false).to_a
      expect(query[5]).to eq(id: '1', order: 1, range: BigDecimal.new(1))
      expect(query[4]).to eq(id: '1', order: 2, range: BigDecimal.new(2))
      expect(query[3]).to eq(id: '1', order: 3, range: BigDecimal.new(3))
      expect(query[2]).to eq(id: '1', order: 4, range: BigDecimal.new(4))
      expect(query[1]).to eq(id: '1', order: 5, range: BigDecimal.new(5))
      expect(query[0]).to eq(id: '1', order: 6, range: BigDecimal.new(6))
    end
  end

  context 'without a preexisting table' do
    # CreateTable and DeleteTable
    it 'performs CreateTable and DeleteTable' do
      table = Dynamoid.adapter.create_table('CreateTable', :id, range_key: { created_at: :number })

      expect(Dynamoid.adapter.list_tables).to include 'CreateTable'

      Dynamoid.adapter.delete_table('CreateTable')
    end

    describe 'create table with secondary index' do
      let(:doc_class) do
        Class.new do
          include Dynamoid::Document
          range range: :number
          field :range2
          field :hash2
        end
      end

      it 'creates table with local_secondary_index' do
        # setup
        doc_class.table(name: 'table_lsi', key: :id)
        doc_class.local_secondary_index ({
          range_key: :range2,
        })

        Dynamoid.adapter.create_table('table_lsi', :id,
          local_secondary_indexes: doc_class.local_secondary_indexes.values,
          range_key: { range: :number })

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_lsi')
        data = resp.data
        lsi = data.table.local_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV2::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV2::TABLE_STATUSES[:active])
        expect(lsi.index_name).to eql 'dynamoid_tests_table_lsi_index_id_range2'
        expect(lsi.key_schema.map(&:to_hash)).to eql [
          {attribute_name: 'id', key_type: 'HASH'},
          {attribute_name: 'range2', key_type: 'RANGE'}
        ]
        expect(lsi.projection.to_hash).to eql ({projection_type: 'KEYS_ONLY'})
      end

      it 'creates table with global_secondary_index' do
        # setup
        doc_class.table(name: 'table_gsi', key: :id)
        doc_class.global_secondary_index ({
          hash_key: :hash2,
          range_key: :range2,
          write_capacity: 10,
          read_capacity: 20

        })
        Dynamoid.adapter.create_table('table_gsi', :id,
          global_secondary_indexes: doc_class.global_secondary_indexes.values,
          range_key: { range: :number })

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_gsi')
        data = resp.data
        gsi = data.table.global_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV2::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV2::TABLE_STATUSES[:active])
        expect(gsi.index_name).to eql 'dynamoid_tests_table_gsi_index_hash2_range2'
        expect(gsi.key_schema.map(&:to_hash)).to eql [
          {attribute_name: 'hash2', key_type: 'HASH'},
          {attribute_name: 'range2', key_type: 'RANGE'}
        ]
        expect(gsi.projection.to_hash).to eql ({projection_type: 'KEYS_ONLY'})
        expect(gsi.provisioned_throughput.write_capacity_units).to eql 10
        expect(gsi.provisioned_throughput.read_capacity_units).to eql 20
      end
    end
  end

  context 'with a preexisting table' do
    # GetItem, PutItem and DeleteItem
    it 'performs GetItem for an item that does not exist' do
      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'performs GetItem for an item that does exist' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq(name: 'Josh', id: '1')

      Dynamoid.adapter.delete_item(test_table1, '1')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'performs GetItem for an item that does exist with a range key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 2.0)

      expect(Dynamoid.adapter.get_item(test_table3, '1', range_key: 2.0)).to eq(name: 'Josh', id: '1', range: 2.0)

      Dynamoid.adapter.delete_item(test_table3, '1', range_key: 2.0)

      expect(Dynamoid.adapter.get_item(test_table3, '1', range_key: 2.0)).to be_nil
    end

    it 'performs DeleteItem for an item that does not exist' do
      Dynamoid.adapter.delete_item(test_table1, '1')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
    end

    it 'performs PutItem for an item that does not exist' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq(id: '1', name: 'Josh')
    end

    # BatchGetItem
    it 'passes options to underlying BatchGet call' do
      pending 'at the moment passing the options to underlying batch get is not supported'
      expect_any_instance_of(Aws::DynamoDB::Client).to receive(:batch_get_item).with(request_items: {test_table1 => {keys: [{'id' => '1'}, {'id' => '2'}], consistent_read: true}}).and_call_original
      described_class.batch_get_item({test_table1 => ['1', '2']}, consistent_read: true)
    end

    it 'performs BatchGetItem with singular keys' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table2, id: '1', name: 'Justin')

      results = Dynamoid.adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      expect(results.size).to eq 2
      expect(results[test_table1]).to include(name: 'Josh', id: '1')
      expect(results[test_table2]).to include(name: 'Justin', id: '1')
    end

    it 'performs BatchGetItem with multiple keys' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      results = Dynamoid.adapter.batch_get_item(test_table1 => ['1', '2'])
      expect(results.size).to eq 1
      expect(results[test_table1]).to include(name: 'Josh', id: '1')
      expect(results[test_table1]).to include(name: 'Justin', id: '2')
    end

    it 'performs BatchGetItem with one ranged key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', name: 'Justin', range: 2.0)

      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0]])
      expect(results.size).to eq 1
      expect(results[test_table3]).to include(name: 'Josh', id: '1', range: 1.0)
    end

    it 'performs BatchGetItem with multiple ranged keys' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', name: 'Justin', range: 2.0)

      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0], ['2', 2.0]])
      expect(results.size).to eq 1

      expect(results[test_table3]).to include(name: 'Josh', id: '1', range: 1.0)
      expect(results[test_table3]).to include(name: 'Justin', id: '2', range: 2.0)
    end

    it 'performs BatchGetItem with ranges of 100 keys' do
      table_ids = []

      (1..101).each do |i|
        id, range = i.to_s, i.to_f
        Dynamoid.adapter.put_item(test_table3, id: id, name: "Josh_#{i}", range: range)
        table_ids << [id, range]
      end

      results = Dynamoid.adapter.batch_get_item(test_table3 => table_ids)

      expect(results.size).to eq 1

      expect(results[test_table3]).to include(name: 'Josh_101', id: '101', range: 101.0)
    end

    # BatchDeleteItem
    it 'performs BatchDeleteItem with singular keys' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table2, id: '1', name: 'Justin')

      Dynamoid.adapter.batch_delete_item(test_table1 => ['1'], test_table2 => ['1'])

      results = Dynamoid.adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      expect(results.size).to eq 2

      expect(results[test_table1]).to be_blank
      expect(results[test_table2]).to be_blank
    end

    it 'performs BatchDeleteItem with multiple keys' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      Dynamoid.adapter.batch_delete_item(test_table1 => ['1', '2'])

      results = Dynamoid.adapter.batch_get_item(test_table1 => ['1', '2'])

      expect(results.size).to eq 1
      expect(results[test_table1]).to be_blank
    end

    it 'performs BatchDeleteItem with one ranged key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', name: 'Justin', range: 2.0)

      Dynamoid.adapter.batch_delete_item(test_table3 => [['1', 1.0]])
      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0]])

      expect(results.size).to eq 1
      expect(results[test_table3]).to be_blank
    end

    it 'performs BatchDeleteItem with multiple ranged keys' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', name: 'Justin', range: 2.0)

      Dynamoid.adapter.batch_delete_item(test_table3 => [['1', 1.0], ['2', 2.0]])
      results = Dynamoid.adapter.batch_get_item(test_table3 => [['1', 1.0], ['2', 2.0]])

      expect(results.size).to eq 1
      expect(results[test_table3]).to be_blank
    end

    it 'performs BatchDeleteItem with more than 25 items' do
      (25 + 1).times do |i|
        Dynamoid.adapter.put_item(test_table1, id: i.to_s)
      end

      expect(Dynamoid.adapter.client).to receive(:batch_write_item)
        .exactly(2).times.and_call_original
      Dynamoid.adapter.batch_delete_item(test_table1 => (0 .. 25).map(&:to_s))

      results = Dynamoid.adapter.scan(test_table1)
      expect(results.to_a.size).to eq 0
    end

    it 'performs BatchDeleteItem with more than 25 items and different tables' do
      13.times do |i|
        Dynamoid.adapter.put_item(test_table1, id: i.to_s)
        Dynamoid.adapter.put_item(test_table2, id: i.to_s)
      end

      expect(Dynamoid.adapter.client).to receive(:batch_write_item)
        .exactly(2).times.and_call_original
      Dynamoid.adapter.batch_delete_item(
        test_table1 => (0 .. 12).map(&:to_s),
        test_table2 => (0 .. 12).map(&:to_s))

      results = Dynamoid.adapter.scan(test_table1)
      expect(results.to_a.size).to eq 0

      results = Dynamoid.adapter.scan(test_table2)
      expect(results.to_a.size).to eq 0
    end

    describe '#batch_write_item' do
      it 'creates several items at once' do
        Dynamoid.adapter.batch_write_item(test_table3, [
          {id: '1', range: 1.0},
          {id: '2', range: 2.0},
          {id: '3', range: 3.0}
        ])

        results = Dynamoid.adapter.scan(test_table3)
        expect(results.to_a).to contain_exactly(
          {id: '1', range: 1.0},
          {id: '2', range: 2.0},
          {id: '3', range: 3.0}
        )
      end

      it 'performs BatchDeleteItem with more than 25 items' do
        items = (1 .. 26).map { |i| {id: i.to_s} }

        expect(Dynamoid.adapter.client).to receive(:batch_write_item)
          .exactly(2).times.and_call_original

        Dynamoid.adapter.batch_write_item(test_table1, items)
      end
    end

    # ListTables
    it 'performs ListTables' do
      # Force creation of the tables
      test_table1; test_table2; test_table3; test_table4

      expect(Dynamoid.adapter.list_tables).to include test_table1
      expect(Dynamoid.adapter.list_tables).to include test_table2
    end

    # Query
    it 'performs query on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.query(test_table1, hash_value: '1').first).to eq(id: '1', name: 'Josh')
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      expect(Dynamoid.adapter.query(test_table1, hash_value: '1').first).to eq(id: '1', name: 'Josh')
    end

    it_behaves_like 'range queries'

    describe 'query' do
      include_examples 'correctly handling limits', :query
    end

    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, name: {eq: 'Josh'}).to_a).to eq [{ id: '1', name: 'Josh' }]
    end

    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      expect(Dynamoid.adapter.scan(test_table1, name: {eq: 'Josh'}).to_a).to eq [{ id: '1', name: 'Josh' }]
    end

    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, name: {eq: 'Josh'})).to include({name: 'Josh', id: '2'}, name: 'Josh', id: '1')
    end

    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {})).to include({name: 'Josh', id: '2'}, name: 'Josh', id: '1')
    end

    it 'performs scan on a table and returns correct limit' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, record_limit: 1).count).to eq(1)
    end

    it 'performs scan on a table and returns correct batch' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, batch_size: 1).count).to eq(4)
    end

    it 'performs scan on a table and returns correct limit and batch' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, record_limit: 1, batch_size: 1).count).to eq(1)
    end

    describe 'scans' do
      it_behaves_like 'correctly handling limits', :scan
    end

    # Truncate
    it 'performs truncate on an existing table' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Pascal')

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq(name: 'Josh', id: '1')
      expect(Dynamoid.adapter.get_item(test_table1, '2')).to eq(name: 'Pascal', id: '2')

      Dynamoid.adapter.truncate(test_table1)

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil
      expect(Dynamoid.adapter.get_item(test_table1, '2')).to be_nil
    end

    it 'performs truncate on an existing table with a range key' do
      Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: 1.0)
      Dynamoid.adapter.put_item(test_table3, id: '2', name: 'Justin', range: 2.0)

      Dynamoid.adapter.truncate(test_table3)

      expect(Dynamoid.adapter.get_item(test_table3, '1', range_key: 1.0)).to be_nil
      expect(Dynamoid.adapter.get_item(test_table3, '2', range_key: 2.0)).to be_nil
    end

    it_behaves_like 'correct ordering'
  end

  # DescribeTable

  # UpdateItem

  # UpdateTable
end
