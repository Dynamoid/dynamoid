# frozen_string_literal: true

require 'dynamoid/adapter_plugin/aws_sdk_v3'
require 'spec_helper'

describe Dynamoid::AdapterPlugin::AwsSdkV3 do
  #
  # These let() definitions create tables "dynamoid_tests_TestTable<N>" and return the
  # name of the table.
  #
  # Name => Constructor args
  {
    1 => [:id],
    2 => [:id],
    3 => [:id, { range_key: { range: :number } }],
    4 => [:id, { range_key: { range: :number } }],
    5 => [:id, { read_capacity: 10_000, write_capacity: 1000 }]
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
    before do
      @request_type = request_type
    end

    def query_key_conditions
      { id: [[:eq, '1']] }
    end

    def dynamo_request(table_name, conditions = {}, options = {})
      if @request_type == :query
        Dynamoid.adapter.query(table_name, query_key_conditions, conditions, options).flat_map { |i| i }
      else
        Dynamoid.adapter.scan(table_name, conditions, options).flat_map { |i| i }
      end
    end

    context 'multiple name entities' do
      before do
        (1..4).each do |i|
          Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Josh', range: i.to_f)
          Dynamoid.adapter.put_item(test_table3, id: '1', name: 'Pascal', range: (i + 4).to_f)
        end
      end

      it 'returns correct records' do
        expect(dynamo_request(test_table3).count).to eq(8)
      end

      it 'returns correct record limit' do
        expect(dynamo_request(test_table3, {}, { record_limit: 1 }).count).to eq(1)
        expect(dynamo_request(test_table3, {}, { record_limit: 3 }).count).to eq(3)
      end

      it 'returns correct batch' do
        # Receives 8 times for each item and 1 more for empty page
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(9).times.and_call_original
        expect(dynamo_request(test_table3, {}, { batch_size: 1 }).count).to eq(8)
      end

      it 'returns correct batch and paginates in batches' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(3).times.and_call_original
        expect(dynamo_request(test_table3, {}, { batch_size: 3 }).count).to eq(8)
      end

      it 'returns correct record limit and batch' do
        expect(dynamo_request(test_table3, {}, { record_limit: 1, batch_size: 1 }).count).to eq(1)
      end

      it 'returns correct record limit with filter' do
        expect(
          dynamo_request(test_table3, { name: [[:eq, 'Josh']] }, { record_limit: 1 }).count
        ).to eq(1)
      end

      it 'obeys correct scan limit with filter' do
        expect(Dynamoid.adapter.client).to receive(request_type).once.and_call_original
        expect(
          dynamo_request(test_table3, { name: [[:eq, 'Josh']] }, { scan_limit: 2 }).count
        ).to eq(2)
      end

      it 'obeys correct scan limit over record limit with filter' do
        expect(Dynamoid.adapter.client).to receive(request_type).once.and_call_original
        expect(
          dynamo_request(
            test_table3,
            { name: [[:eq, 'Josh']] },
            {
              scan_limit: 2,
              record_limit: 10 # Won't be able to return more than 2 due to scan limit
            }
          ).count
        ).to eq(2)
      end

      it 'obeys correct scan limit with filter with some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).once.and_call_original
        expect(
          dynamo_request(test_table3, { name: [[:eq, 'Pascal']] }, { scan_limit: 5 }).count
        ).to eq(1)
      end

      it 'obeys correct scan limit and batch size with filter with some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).twice.and_call_original
        expect(
          dynamo_request(
            test_table3,
            { name: [[:eq, 'Josh']] },
            {
              scan_limit: 3,
              batch_size: 2 # This would force batching of size 2 for potential of 4 results!
            }
          ).count
        ).to eq(3)
      end

      it 'obeys correct scan limit with filter and batching for some return' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(5).times.and_call_original
        # We should paginate through 5 responses each of size 1 (batch) and
        # only scan through 5 records at most which with our given filter
        # should return 1 result since first 4 are Josh and last is Pascal.
        expect(
          dynamo_request(
            test_table3,
            { name: [[:eq, 'Pascal']] },
            {
              batch_size: 1,
              scan_limit: 5,
              record_limit: 3
            }
          ).count
        ).to eq(1)
      end

      it 'obeys correct record limit with filter, batching, and scan limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(6).times.and_call_original
        # We should paginate through 6 responses each of size 1 (batch) and
        # only scan through 6 records at most which with our given filter
        # should return 2 results, and hit record limit before scan limit.
        expect(
          dynamo_request(
            test_table3,
            { name: [[:eq, 'Pascal']] },
            {
              batch_size: 1,
              scan_limit: 10,
              record_limit: 2
            }
          ).count
        ).to eq(2)
      end
    end

    #
    # Tests that even with large records we are paginating to pull more data
    # even if we hit response data size limits
    #
    context 'large records still returns as much data' do
      before do
        # 64 of these items will exceed the 1MB result record_limit thus query won't return all results on first loop
        # We use :age since :range won't work for filtering in queries
        200.times do |i|
          Dynamoid.adapter.put_item(
            test_table3,
            id: '1',
            range: i.to_f,
            age: i.to_f,
            data: 'A' * 1024 * 16
          )
        end
      end

      it 'returns correct for limits and scan limit' do
        expect(dynamo_request(test_table3, {}, { scan_limit: 100 }).count).to eq(100)
      end

      it 'returns correct for scan limit with filtering' do
        # Not sure why there is difference but :query will do 1 page and see 100 records and filter out 10
        # while :scan will do 2 pages and see 64 records on first page similar to the 1MB return limit
        # and then look at 36 records and find 10 on the second page.
        pages = request_type == :query ? 1 : 2
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(pages).times.and_call_original
        expect(
          dynamo_request(test_table3, { age: [[:gte, 90.0]] }, { scan_limit: 100 }).count
        ).to eq(10)
      end

      it 'returns correct for record limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).twice.and_call_original
        expect(
          dynamo_request(test_table3, { age: [[:gte, 5.0]] }, { record_limit: 100 }).count
        ).to eq(100)
      end

      it 'returns correct record limit with filtering' do
        expect(
          dynamo_request(test_table3, { age: [[:gte, 133.0]] }, { record_limit: 100 }).count
        ).to eq(67)
      end

      it 'returns correct with batching' do
        # Since we hit the data size limit 3 times, so we must make 4 requests
        # which is limitation of DynamoDB and therefore batch limit is
        # restricted by this limitation as well!
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(4).times.and_call_original
        expect(dynamo_request(test_table3, {}, { batch_size: 100 }).count).to eq(200)
      end

      it 'returns correct with batching and record limit beyond data size limit' do
        # Since we hit limit once, we need to make sure the second request only
        # requests for as many as we have left for our record limit.
        expect(Dynamoid.adapter.client).to receive(request_type).twice.and_call_original
        expect(
          dynamo_request(test_table3, {}, { record_limit: 83, batch_size: 100 }).count
        ).to eq(83)
      end

      it 'returns correct with batching and record limit' do
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(11).times.and_call_original
        # Since we do age >= 5.0 we lose the first 5 results so we make 11 paginated requests
        expect(
          dynamo_request(
            test_table3,
            { age: [[:gte, 5.0]] },
            {
              record_limit: 100,
              batch_size: 10
            }
          ).count
        ).to eq(100)
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

      expect(Dynamoid.adapter.client).to receive(request_type).twice.and_call_original
      # In faulty code, the record limit would adjust limit to 2 thus on second page
      # we would get the 5th Josh (range value 6.0) whereas correct implementation would
      # adjust limit to 1 since can only scan 1 more record therefore would see Pascal
      # and not go to next valid record.
      expect(
        dynamo_request(
          test_table3,
          { name: [[:eq, 'Josh']] },
          {
            batch_size: 4,
            scan_limit: 5, # Scan limit would adjust requested limit to 1
            record_limit: 6 # Record limit would adjust requested limit to 2
          }
        ).count
      ).to eq(4)
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
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:between, [0.0, 3.0]]] }).to_a).to eq [[[{ id: '1', range: BigDecimal('1') }, { id: '1', range: BigDecimal('3') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table with a range and selects items in a range with :select option' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:between, [0.0, 3.0]]] }, {}, { select: 'ALL_ATTRIBUTES' }).to_a).to eq [[[{ id: '1', range: BigDecimal('1') }, { id: '1', range: BigDecimal('3') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table with a range and selects items greater than' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:gt, 1.0]] }).to_a).to eq [[[{ id: '1', range: BigDecimal('3') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table with a range and selects items less than' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:lt, 2.0]] }).to_a).to eq [[[{ id: '1', range: BigDecimal('1') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table with a range and selects items gte' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:gte, 1.0]] }).to_a).to eq [[[{ id: '1', range: BigDecimal('1') }, { id: '1', range: BigDecimal('3') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table with a range and selects items lte' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:lte, 3.0]] }).to_a).to eq [[[{ id: '1', range: BigDecimal('1') }, { id: '1', range: BigDecimal('3') }], { last_evaluated_key: nil }]]
    end

    it 'performs query on a table and returns items based on returns correct limit' do
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:gt, 0.0]] }, {}, { record_limit: 1 }).flat_map { |i| i }.count).to eq(1)
    end

    it 'performs query on a table with a range and selects all items' do
      200.times { |i| Dynamoid.adapter.put_item(test_table3, id: '1', range: i.to_f, data: 'A' * 1024 * 16) }
      # 64 of these items will exceed the 1MB result limit thus query won't return all results on first loop
      expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']], range: [[:gte, 0.0]] }).flat_map { |i| i }.count).to eq(200)
    end
  end

  #
  # Tests scan_index_forwards flag behavior on range queries
  #
  shared_examples 'correct ordering' do
    before do
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 1, range: 1.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 2, range: 2.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 3, range: 3.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 4, range: 4.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 5, range: 5.0)
      Dynamoid.adapter.put_item(test_table4, id: '1', order: 6, range: 6.0)
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
      query = Dynamoid.adapter.query(test_table4, { id: [[:eq, '1']], range: [[:gt, 0]] }, {}, { scan_index_forward: true }).flat_map { |i| i }.to_a
      expect(query[0]).to eq(id: '1', order: 1, range: BigDecimal('1'))
      expect(query[1]).to eq(id: '1', order: 2, range: BigDecimal('2'))
      expect(query[2]).to eq(id: '1', order: 3, range: BigDecimal('3'))
      expect(query[3]).to eq(id: '1', order: 4, range: BigDecimal('4'))
      expect(query[4]).to eq(id: '1', order: 5, range: BigDecimal('5'))
      expect(query[5]).to eq(id: '1', order: 6, range: BigDecimal('6'))
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
      query = Dynamoid.adapter.query(test_table4, { id: [[:eq, '1']], range: [[:gt, 0]] }, {}, { scan_index_forward: false }).flat_map { |i| i }.to_a
      expect(query[5]).to eq(id: '1', order: 1, range: BigDecimal('1'))
      expect(query[4]).to eq(id: '1', order: 2, range: BigDecimal('2'))
      expect(query[3]).to eq(id: '1', order: 3, range: BigDecimal('3'))
      expect(query[2]).to eq(id: '1', order: 4, range: BigDecimal('4'))
      expect(query[1]).to eq(id: '1', order: 5, range: BigDecimal('5'))
      expect(query[0]).to eq(id: '1', order: 6, range: BigDecimal('6'))
    end
  end

  describe '#batch_get_item' do
    let(:table)                    { "#{Dynamoid::Config.namespace}_table" }
    let(:table_another)            { "#{Dynamoid::Config.namespace}_table_another" }
    let(:table_with_composite_key) { "#{Dynamoid::Config.namespace}_table_with_composite_key" }

    before do
      Dynamoid.adapter.create_table(table, :id)
      Dynamoid.adapter.create_table(table_another, :id)
      Dynamoid.adapter.create_table(table_with_composite_key, :id, range_key: { age: :number })
    end

    after do
      Dynamoid.adapter.delete_table(table)
      Dynamoid.adapter.delete_table(table_another)
      Dynamoid.adapter.delete_table(table_with_composite_key)
    end

    it 'passes options to underlying BatchGet call' do
      pending 'at the moment passing the options to underlying batch get is not supported'

      expect_any_instance_of(Aws::DynamoDB::Client).to receive(:batch_get_item).with(request_items: { test_table1 => { keys: [{ 'id' => '1' }, { 'id' => '2' }], consistent_read: true } }).and_call_original
      described_class.batch_get_item({ test_table1 => %w[1 2] }, consistent_read: true)
    end

    it 'loads multiple items at once' do
      Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(table, id: '2', name: 'Justin')

      results = Dynamoid.adapter.batch_get_item(table => %w[1 2])
      expect(results).to eq(
        {
          table => [
            { id: '1', name: 'Josh' },
            { id: '2', name: 'Justin' },
          ]
        }
      )
    end

    it 'loads items from multiple tables' do
      Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(table_another, id: '2', name: 'Justin')

      results = Dynamoid.adapter.batch_get_item(table => ['1'], table_another => ['2'])
      expect(results).to eq(
        {
          table => [
            { id: '1', name: 'Josh' }
          ],
          table_another => [
            { id: '2', name: 'Justin' }
          ]
        }
      )
    end

    it 'performs BatchGetItem API call' do
      expect(Dynamoid.adapter.client).to receive(:batch_get_item).and_call_original
      Dynamoid.adapter.batch_get_item(table => ['1'])
    end

    it 'accepts [] as an ids list' do
      results = Dynamoid.adapter.batch_get_item(table => [])
      expect(results).to eq(table => [])
    end

    it 'accepts {} as table_names_with_ids argument' do
      results = Dynamoid.adapter.batch_get_item({})
      expect(results).to eq({})
    end

    it 'accepts table name as String and as Symbol' do
      Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')

      results = Dynamoid.adapter.batch_get_item(table.to_s => ['1'])
      expect(results).to eq(table => [{ id: '1', name: 'Josh' }])

      results = Dynamoid.adapter.batch_get_item(table.to_sym => ['1'])
      expect(results).to eq(table => [{ id: '1', name: 'Josh' }])
    end

    context 'when simple key' do
      it 'accepts one id passed as singular value' do
        Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')

        results = Dynamoid.adapter.batch_get_item(table => '1')
        expect(results).to eq(table => [{ id: '1', name: 'Josh' }])
      end

      it 'accepts one id passed as array' do
        Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')

        results = Dynamoid.adapter.batch_get_item(table => ['1'])
        expect(results).to eq(table => [{ id: '1', name: 'Josh' }])
      end

      it 'accepts multiple ids' do
        Dynamoid.adapter.put_item(table, id: '1', name: 'Josh')
        Dynamoid.adapter.put_item(table, id: '2', name: 'Justin')

        results = Dynamoid.adapter.batch_get_item(table => %w[1 2])
        expect(results).to eq(
          {
            table => [
              { id: '1', name: 'Josh' },
              { id: '2', name: 'Justin' },
            ]
          }
        )
      end
    end

    context 'when composite primary key' do
      it 'accepts one id passed as singular value' do
        skip 'It is not supported and needed yet'

        Dynamoid.adapter.put_item(table_with_composite_key, id: '1', age: 29, name: 'Josh')

        results = Dynamoid.adapter.batch_get_item(table_with_composite_key => ['1', 29])
        expect(results).to eq(table_with_composite_key => [{ id: '1', age: 29, name: 'Josh' }])
      end

      it 'accepts one id passed as array' do
        Dynamoid.adapter.put_item(table_with_composite_key, id: '1', age: 29, name: 'Josh')

        results = Dynamoid.adapter.batch_get_item(table_with_composite_key => [['1', 29]])
        expect(results).to eq(table_with_composite_key => [{ id: '1', age: 29, name: 'Josh' }])
      end

      it 'accepts multiple ids' do
        Dynamoid.adapter.put_item(table_with_composite_key, id: '1', age: 29, name: 'Josh')
        Dynamoid.adapter.put_item(table_with_composite_key, id: '2', age: 16, name: 'Justin')

        results = Dynamoid.adapter.batch_get_item(table_with_composite_key => [['1', 29], ['2', 16]])

        expect(results).to match(
          {
            table_with_composite_key => contain_exactly(
              { id: '1', age: BigDecimal('29'), name: 'Josh' },
              { id: '2', age: BigDecimal('16'), name: 'Justin' },
            )
          }
        )
      end
    end

    it 'can load any number of items (even more than 100)' do
      ids = (1..101).map(&:to_s)

      ids.each do |id|
        Dynamoid.adapter.put_item(table, id: id)
      end

      results = Dynamoid.adapter.batch_get_item(table => ids)
      items = results[table]

      expect(items.size).to eq 101
    end

    it 'loads unprocessed items for a table without a range key' do
      # BatchGetItem has following limitations:
      # * up to 100 items at once
      # * up to 16 MB at once
      # * one item size up to 400 KB (common limitation)
      #
      # To reach limits we will write as large data as possible
      # and then read it back
      #
      # 100 * 400 KB = ~40 MB
      # 40 MB / 16 MB ~ 3
      # So we expect BatchGetItem to be called 3 times
      #
      # '9' is an experimentally founded value
      # it includes lenght('id' + 'text') + some not documented overhead (1-100 bytes)

      ids = (1..100).map(&:to_s)

      ids.each do |id|
        text = '#' * (400.kilobytes - 9)
        Dynamoid.adapter.put_item(table, id: id, text: text)
      end

      expect(Dynamoid.adapter.client).to receive(:batch_get_item)
        .exactly(3)
        .times.and_call_original

      results = Dynamoid.adapter.batch_get_item(table => ids)
      items = results[table]

      expect(items.size).to eq 100
      expect(items.map { |h| h[:id] }).to match_array(ids)
    end

    it 'loads unprocessed items for a table with a range key' do
      # BatchGetItem has following limitations:
      # * up to 100 items at once
      # * up to 16 MB at once
      # * one item size up to 400 KB (common limitation)
      #
      # To reach limits we will write as large data as possible
      # and then read it back
      #
      # 100 * 400 KB = ~40 MB
      # 40 MB / 16 MB ~ 3
      # So we expect BatchGetItem to be called 3 times
      #
      # '15' is an experimentally found value
      # it includes the size of ('id' + 'age') + some not documented overhead

      ids = (1..100).map { |id| [id.to_s, id] }

      ids.each do |id, age|
        text = '#' * (400.kilobytes - 15)
        Dynamoid.adapter.put_item(table_with_composite_key, id: id, age: age, name: text)
      end

      expect(Dynamoid.adapter.client).to receive(:batch_get_item)
        .exactly(3)
        .times.and_call_original

      results = Dynamoid.adapter.batch_get_item(table_with_composite_key => ids)
      items = results[table_with_composite_key]

      expect(items.size).to eq(100)
      expect(items.map { |h| [h[:id], h[:age]] }).to match_array(ids)
    end

    context 'when called with block' do
      it 'returns nil' do
        Dynamoid.adapter.put_item(table, id: '1')
        results = Dynamoid.adapter.batch_get_item(table => '1') { |batch, _| batch }

        expect(results).to be_nil
      end

      it 'calles block for each loaded items batch' do
        ids = (1..110).map(&:to_s)

        ids.each do |id|
          Dynamoid.adapter.put_item(table, id: id)
        end

        batches = []
        Dynamoid.adapter.batch_get_item(table => ids) do |batch|
          batches << batch
        end

        # expect only 2 batches: 1-100 and 101-110
        expect(batches.size).to eq 2
        batch1, batch2 = batches

        expect(batch1.keys).to eq [table]
        expect(batch1[table].size).to eq 100

        expect(batch2.keys).to eq [table]
        expect(batch2[table].size).to eq 10

        actual_ids = (batch1[table] + batch2[table]).map { |h| h[:id] }
        expect(actual_ids).to match_array(ids)
      end

      it 'passes as block arguments flag if there are unprocessed items for each batch' do
        # It should be enough to exceed limit of 16 MB per call
        # 50 * 400KB = ~20 MB
        # 9 bytes = length('id' + 'text') + some not documented overhead (1-100 bytes)

        ids = (1..50).map(&:to_s)

        ids.each do |id|
          text = '#' * (400.kilobytes - 9)
          Dynamoid.adapter.put_item(table, id: id, text: text)
        end

        complete_statuses = []
        Dynamoid.adapter.batch_get_item(table => ids) do |_, not_completed|
          complete_statuses << not_completed
        end

        expect(complete_statuses).to eq [true, false]
      end
    end
  end

  context 'without a preexisting table' do
    # CreateTable and DeleteTable
    it 'performs CreateTable and DeleteTable' do
      table = Dynamoid.adapter.create_table('CreateTable', :id, range_key: { created_at: :number })

      expect(Dynamoid.adapter.list_tables).to include 'CreateTable'

      Dynamoid.adapter.delete_table('CreateTable')
    end

    it 'creates table synchronously' do
      table = Dynamoid.adapter.create_table('snakes', :id, sync: true)

      expect(Dynamoid.adapter.list_tables).to include 'snakes'

      Dynamoid.adapter.delete_table('snakes')
    end

    it 'deletes table synchronously' do
      table = Dynamoid.adapter.create_table('snakes', :id, sync: true)
      expect(Dynamoid.adapter.list_tables).to include 'snakes'

      Dynamoid.adapter.delete_table('snakes', sync: true)
      expect(Dynamoid.adapter.list_tables).not_to include 'snakes'
    end

    describe 'create table with secondary index' do
      let(:doc_class) do
        Class.new do
          include Dynamoid::Document
          range :range, :number
          field :range2
          field :hash2
        end
      end

      it 'creates table with local_secondary_index' do
        # setup
        doc_class.table(name: 'table_lsi', key: :id)
        doc_class.local_secondary_index(
          range_key: :range2
        )

        Dynamoid.adapter.create_table(
          'table_lsi',
          :id,
          local_secondary_indexes: doc_class.local_secondary_indexes.values,
          range_key: { range: :number }
        )

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_lsi')
        data = resp.data
        lsi = data.table.local_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV3::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV3::TABLE_STATUSES[:active])
        expect(lsi.index_name).to eql 'dynamoid_tests_table_lsi_index_id_range2'
        expect(lsi.key_schema.map(&:to_hash)).to eql [
          { attribute_name: 'id', key_type: 'HASH' },
          { attribute_name: 'range2', key_type: 'RANGE' }
        ]
        expect(lsi.projection.to_hash).to eql(projection_type: 'KEYS_ONLY')
      end

      it 'creates table with global_secondary_index' do
        # setup
        doc_class.table(name: 'table_gsi', key: :id)
        doc_class.global_secondary_index(
          hash_key: :hash2,
          range_key: :range2,
          write_capacity: 10,
          read_capacity: 20
        )
        Dynamoid.adapter.create_table(
          'table_gsi',
          :id,
          global_secondary_indexes: doc_class.global_secondary_indexes.values,
          range_key: { range: :number }
        )

        # execute
        resp = Dynamoid.adapter.client.describe_table(table_name: 'table_gsi')
        data = resp.data
        gsi = data.table.global_secondary_indexes.first

        # test
        expect(Dynamoid::AdapterPlugin::AwsSdkV3::PARSE_TABLE_STATUS.call(resp)).to eq(Dynamoid::AdapterPlugin::AwsSdkV3::TABLE_STATUSES[:active])
        expect(gsi.index_name).to eql 'dynamoid_tests_table_gsi_index_hash2_range2'
        expect(gsi.key_schema.map(&:to_hash)).to eql [
          { attribute_name: 'hash2', key_type: 'HASH' },
          { attribute_name: 'range2', key_type: 'RANGE' }
        ]
        expect(gsi.projection.to_hash).to eql(projection_type: 'KEYS_ONLY')
        expect(gsi.provisioned_throughput.write_capacity_units).to eql 10
        expect(gsi.provisioned_throughput.read_capacity_units).to eql 20
      end
    end
  end

  context 'with a preexisting table' do
    # GetItem, PutItem and DeleteItem
    it 'passes options to underlying GetItem call' do
      expect(Dynamoid.adapter.client).to receive(:get_item).with(hash_including(consistent_read: true)).and_call_original
      expect(Dynamoid.adapter.get_item(test_table1, '1', consistent_read: true)).to be_nil
    end

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

      Dynamoid.adapter.batch_delete_item(test_table1 => %w[1 2])

      results = Dynamoid.adapter.batch_get_item(test_table1 => %w[1 2])

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
        .twice.and_call_original
      Dynamoid.adapter.batch_delete_item(test_table1 => (0..25).map(&:to_s))

      results = Dynamoid.adapter.scan(test_table1).flat_map { |i| i }
      expect(results.to_a.size).to eq 0
    end

    it 'performs BatchDeleteItem with more than 25 items and different tables' do
      13.times do |i|
        Dynamoid.adapter.put_item(test_table1, id: i.to_s)
        Dynamoid.adapter.put_item(test_table2, id: i.to_s)
      end

      expect(Dynamoid.adapter.client).to receive(:batch_write_item)
        .twice.and_call_original
      Dynamoid.adapter.batch_delete_item(
        test_table1 => (0..12).map(&:to_s),
        test_table2 => (0..12).map(&:to_s)
      )

      results = Dynamoid.adapter.scan(test_table1).flat_map { |i| i }
      expect(results.to_a.size).to eq 0

      results = Dynamoid.adapter.scan(test_table2).flat_map { |i| i }
      expect(results.to_a.size).to eq 0
    end

    describe '#batch_write_item' do
      it 'creates several items at once' do
        Dynamoid.adapter.batch_write_item(test_table3, [
                                            { id: '1', range: 1.0 },
                                            { id: '2', range: 2.0 },
                                            { id: '3', range: 3.0 }
                                          ])

        results = Dynamoid.adapter.scan(test_table3)
        expect(results.to_a.first).to match [
          contain_exactly(
            { id: '1', range: 1.0 },
            { id: '2', range: 2.0 },
            { id: '3', range: 3.0 }
          ),
          { last_evaluated_key: nil }
        ]
      end

      it 'performs BatchDeleteItem with more than 25 items' do
        items = (1..26).map { |i| { id: i.to_s } }

        expect(Dynamoid.adapter.client).to receive(:batch_write_item)
          .twice.and_call_original

        Dynamoid.adapter.batch_write_item(test_table1, items)
      end

      it 'writes unprocessed items' do
        # batch_write_item has following limitations:
        # * up to 25 items at once
        # * up to 16 MB at once
        #
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        ids = (1..3).map(&:to_s)
        items = ids.map { |id| { id: id } }

        records = []
        responses = [
          double('response 1', unprocessed_items: { test_table1 => [
                   double(put_request: double(item: { id: '2' })),
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 2', unprocessed_items: { test_table1 => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item) do |args|
          records << args[:request_items][test_table1].map { |h| h[:put_request][:item] }
          responses.shift
        end

        Dynamoid.adapter.batch_write_item(test_table1, items)
        expect(records).to eq(
          [
            [{ id: '1' }, { id: '2' }, { id: '3' }],
            [{ id: '2' }, { id: '3' }],
            [{ id: '3' }]
          ]
        )
      end

      context 'optional block passed' do
        it 'passes as block arguments flag if there are unprocessed items for each batch' do
          # dynamodb-local ignores provisioned throughput settings
          # so we cannot emulate unprocessed items - let's stub

          responses = [
            double('response 1', unprocessed_items: { test_table1 => [
                     double(put_request: double(item: { id: '25' })) # fail
                   ] }),
            double('response 2', unprocessed_items: nil), # success
            double('response 3', unprocessed_items: { test_table1 => [
                     double(put_request: double(item: { id: '25' })) # fail
                   ] }),
            double('response 4', unprocessed_items: nil) # success
          ]
          allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

          args = []
          items = (1..50).map(&:to_s).map { |id| { id: id } } # the limit is 25 items at once
          Dynamoid.adapter.batch_write_item(test_table1, items) do |has_unprocessed_items|
            args << has_unprocessed_items
          end
          expect(args).to eq [true, false, true, false]
        end
      end
    end

    # ListTables
    it 'performs ListTables' do
      # Force creation of the tables
      test_table1; test_table2; test_table3; test_table4

      expect(Dynamoid.adapter.list_tables).to include test_table1
      expect(Dynamoid.adapter.list_tables).to include test_table2
    end

    context 'when calling ListTables with more than 200 tables' do
      let!(:count_before) { Dynamoid.adapter.list_tables.size }

      before do
        201.times do |n|
          Dynamoid.adapter.create_table("dynamoid_tests_ALotOfTables#{n}", [:id])
        end
      end

      after do
        201.times do |n|
          Dynamoid.adapter.delete_table("dynamoid_tests_ALotOfTables#{n}")
        end
      end

      it 'automatically pages through all results' do
        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_ALotOfTables44'
        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_ALotOfTables200'
        expect(Dynamoid.adapter.list_tables.size).to eq 201 + count_before
      end
    end

    # Query
    it 'performs query on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.query(test_table1, { id: [[:eq, '1']] }).first).to eq([[id: '1', name: 'Josh'], { last_evaluated_key: nil }])
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      expect(Dynamoid.adapter.query(test_table1, { id: [[:eq, '1']] }).first).to eq([[id: '1', name: 'Josh'], { last_evaluated_key: nil }])
    end

    context 'backoff is specified' do
      before do
        @old_backoff = Dynamoid.config.backoff
        @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

        @counter = 0
        Dynamoid.config.backoff_strategies[:simple] = ->(_) { -> { @counter += 1 } }
        Dynamoid.config.backoff = { simple: nil }
      end

      after do
        Dynamoid.config.backoff = @old_backoff
        Dynamoid.config.backoff_strategies = @old_backoff_strategies
      end

      it 'uses specified backoff' do
        Dynamoid.adapter.put_item(test_table3, id: '1', range: 1)
        Dynamoid.adapter.put_item(test_table3, id: '1', range: 2)

        expect(Dynamoid.adapter.query(test_table3, { id: [[:eq, '1']] }, {}, { batch_size: 1 }).flat_map { |i| i }.count).to eq 2
        expect(@counter).to eq 2
      end
    end

    it_behaves_like 'range queries'

    describe 'query' do
      include_examples 'correctly handling limits', :query
    end

    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, name: { eq: 'Josh' }).to_a).to eq [[[{ id: '1', name: 'Josh' }], { last_evaluated_key: nil }]]
    end

    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Justin')

      expect(Dynamoid.adapter.scan(test_table1, name: { eq: 'Josh' }).to_a).to eq [[[{ id: '1', name: 'Josh' }], { last_evaluated_key: nil }]]
    end

    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')

      expect(
        Dynamoid.adapter.scan(test_table1, name: { eq: 'Josh' }).to_a
      ).to match(
        [
          [
            contain_exactly({ name: 'Josh', id: '2' }, { name: 'Josh', id: '1' }),
            { last_evaluated_key: nil }
          ]
        ]
      )
    end

    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}).flat_map { |i| i }).to include({ name: 'Josh', id: '2' }, name: 'Josh', id: '1')
    end

    it 'performs scan on a table and returns correct limit' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, record_limit: 1).flat_map { |i| i }.count).to eq(1)
    end

    it 'performs scan on a table and returns correct batch' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, batch_size: 1).flat_map { |i| i }.count).to eq(4)
    end

    it 'performs scan on a table and returns correct limit and batch' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
      Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

      expect(Dynamoid.adapter.scan(test_table1, {}, record_limit: 1, batch_size: 1).flat_map { |i| i }.count).to eq(1)
    end

    context 'backoff is specified' do
      before do
        @old_backoff = Dynamoid.config.backoff
        @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

        @counter = 0
        Dynamoid.config.backoff_strategies[:simple] = ->(_) { -> { @counter += 1 } }
        Dynamoid.config.backoff = { simple: nil }
      end

      after do
        Dynamoid.config.backoff = @old_backoff
        Dynamoid.config.backoff_strategies = @old_backoff_strategies
      end

      it 'uses specified backoff' do
        Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')
        Dynamoid.adapter.put_item(test_table1, id: '2', name: 'Josh')
        Dynamoid.adapter.put_item(test_table1, id: '3', name: 'Josh')
        Dynamoid.adapter.put_item(test_table1, id: '4', name: 'Josh')

        expect(Dynamoid.adapter.scan(test_table1, {}, batch_size: 1).flat_map { |i| i }.count).to eq 4
        expect(@counter).to eq 4
      end
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
  describe '#update_item' do
    it 'updates an existing item' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      Dynamoid.adapter.update_item(test_table1, '1') do |t|
        t.set(name: 'Justin')
      end

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq(name: 'Justin', id: '1')
    end

    it 'creates a new item' do
      expect(Dynamoid.adapter.get_item(test_table1, '1')).to be_nil

      Dynamoid.adapter.update_item(test_table1, '1') do |t|
        t.set(name: 'Justin')
      end

      expect(Dynamoid.adapter.get_item(test_table1, '1')).to eq(name: 'Justin', id: '1')
    end

    context 'for attribute values' do
      it 'adds attribute values' do
        Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

        Dynamoid.adapter.update_item(test_table1, '1') do |t|
          t.add(age: 1, followers_count: 5)
          t.add(hobbies: %w[skying climbing].to_set)
        end

        expected_attributes = {
          age: 1,
          followers_count: 5,
          hobbies: %w[skying climbing].to_set
        }
        expect(Dynamoid.adapter.get_item(test_table1, '1')).to include(expected_attributes)
      end

      it 'deletes attribute values' do
        Dynamoid.adapter.put_item(test_table1, id: '1', hobbies: %w[skying climbing].to_set)

        Dynamoid.adapter.update_item(test_table1, '1') do |t|
          t.delete(hobbies: ['skying'].to_set)
        end

        expected_attributes = { hobbies: ['climbing'].to_set }
        expect(Dynamoid.adapter.get_item(test_table1, '1')).to include(expected_attributes)
      end

      it 'deletes attributes' do
        Dynamoid.adapter.put_item(test_table1, id: '1', hobbies: %w[skying climbing].to_set, category_id: 1)

        Dynamoid.adapter.update_item(test_table1, '1') do |t|
          t.delete(hobbies: nil)
          t.delete(:category_id)
        end

        expect(Dynamoid.adapter.get_item(test_table1, '1')).not_to include(:hobbies, :category_id)
      end

      it 'sets attribute values' do
        Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

        Dynamoid.adapter.update_item(test_table1, '1') do |t|
          t.set(age: 21)
        end

        expected_attributes = { age: 21 }
        expect(Dynamoid.adapter.get_item(test_table1, '1')).to include(expected_attributes)
      end
    end

    context 'updates item conditionally' do
      it 'raises Exception if condition fails' do
        Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh', age: 17)

        expect do
          Dynamoid.adapter.update_item(test_table1, '1', conditions: { if: { age: 18 } }) do |t|
            t.set(email: 'justin@example.com')
          end
        end.to raise_error(Dynamoid::Errors::ConditionalCheckFailedException)

        excluded_attributes = { email: 'justin@example.com' }
        expect(Dynamoid.adapter.get_item(test_table1, '1')).not_to include(excluded_attributes)
      end

      it 'updates item if condition succeeds' do
        Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh', age: 18)

        Dynamoid.adapter.update_item(test_table1, '1', conditions: { if: { age: 18 } }) do |t|
          t.set(email: 'justin@example.com')
        end

        expected_attributes = { email: 'justin@example.com' }
        expect(Dynamoid.adapter.get_item(test_table1, '1')).to include(expected_attributes)
      end
    end
  end

  # UpdateTable

  describe 'update_time_to_live' do
    let(:table_name) { "#{Dynamoid::Config.namespace}_table_with_expiration" }

    before do
      Dynamoid.adapter.create_table(table_name, :id)
    end

    after do
      Dynamoid.adapter.delete_table(table_name)
    end

    it 'calls UpdateTimeToLive' do
      allow(Dynamoid.adapter.client).to receive(:update_time_to_live).and_call_original
      Dynamoid.adapter.update_time_to_live(table_name, :ttl)
      expect(Dynamoid.adapter.client).to have_received(:update_time_to_live)
        .with(
          table_name: table_name,
          time_to_live_specification: {
            attribute_name: :ttl,
            enabled: true,
          }
        )
    end

    it 'updates a table schema' do
      Dynamoid.adapter.update_time_to_live(table_name, :ttl)

      response = Dynamoid.adapter.client.describe_time_to_live(table_name: table_name)
      expect(response.time_to_live_description.time_to_live_status).to eq 'ENABLED'
      expect(response.time_to_live_description.attribute_name).to eq 'ttl'
    end
  end

  describe '#execute' do
    it 'executes a PartiQL query' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      Dynamoid.adapter.execute("UPDATE #{test_table1} SET name = 'Mike' WHERE id = '1'")

      item = Dynamoid.adapter.get_item(test_table1, '1')
      expect(item[:name]).to eql 'Mike'
    end

    it 'returns items for SELECT statement' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      items = Dynamoid.adapter.execute("SELECT * FROM #{test_table1}")
      expect(items.size).to eql 1
      expect(items).to eql [{ id: '1', name: 'Josh' }]
    end

    it 'returns [] for statements other than SELECT' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      response = Dynamoid.adapter.execute("UPDATE #{test_table1} SET name = 'Mike' WHERE id = '1'")
      expect(response).to eql []

      response = Dynamoid.adapter.execute("INSERT INTO #{test_table1} VALUE { 'id': '2' }")
      expect(response).to eql []

      response = Dynamoid.adapter.execute("DELETE FROM #{test_table1} WHERE id = '1'")
      expect(response).to eql []
    end

    it 'accepts bind parameters as array of values' do
      Dynamoid.adapter.put_item(test_table1, id: '1', name: 'Josh')

      Dynamoid.adapter.execute("UPDATE #{test_table1} SET name = 'Mike' WHERE id = ?", ['1'])

      item = Dynamoid.adapter.get_item(test_table1, '1')
      expect(item[:name]).to eql 'Mike'
    end

    it 'returns [] when WHERE condition evaluated to false' do
      expect(Dynamoid.adapter.scan_count(test_table1)).to eql 0

      response = Dynamoid.adapter.execute("SELECT * FROM #{test_table1} WHERE id = '1'")
      expect(response.to_a).to eql []

      response = Dynamoid.adapter.execute("UPDATE #{test_table1} SET name = 'Mike' WHERE id = '1'")
      expect(response.to_a).to eql []

      response = Dynamoid.adapter.execute("DELETE FROM #{test_table1} WHERE id = '1'")
      expect(response.to_a).to eql []
    end

    it 'accepts :consistent_read option' do
      expect(Dynamoid.adapter.client).to receive(:execute_statement)
        .with(including(consistent_read: true))
        .and_call_original

      Dynamoid.adapter.execute("SELECT * FROM #{test_table1} WHERE id = '1'", [], consistent_read: true)

      expect(Dynamoid.adapter.client).to receive(:execute_statement)
        .with(including(consistent_read: false))
        .and_call_original

      Dynamoid.adapter.execute("SELECT * FROM #{test_table1} WHERE id = '1'", [], consistent_read: false)
    end

    it 'loads lazily all the pages of a paginated result' do
      next_token = double('next-token')
      obj1 = { 'attribute1' => 1 }
      obj2 = { 'attribute2' => 2 }
      obj3 = { 'attribute3' => 3 }
      obj4 = { 'attribute4' => 4 }
      response1 = double('response-1', next_token: next_token, items: [obj1, obj2])
      response2 = double('response-1', next_token: nil, items: [obj3, obj4])

      expect(Dynamoid.adapter.client).to receive(:execute_statement)
        .and_return(response1, response2)

      items = Dynamoid.adapter.execute('PartlySQL statement')
      expect(items).to be_a(Enumerator::Lazy)
      expect(items.to_a).to eql [
        { attribute1: 1 },
        { attribute2: 2 },
        { attribute3: 3 },
        { attribute4: 4 }
      ]
    end
  end

  # connection_config
  describe '#connectin_config' do
    subject { described_class.new.connection_config }

    before do
      Dynamoid.configure.http_open_timeout = 30
    end

    it 'not nil options entried' do
      expect(subject.keys).to contain_exactly(:endpoint, :log_formatter, :log_level, :logger, :http_open_timeout)
      expect(subject[:http_open_timeout]).to eq 30
    end
  end
end
