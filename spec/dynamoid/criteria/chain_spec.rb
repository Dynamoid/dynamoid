# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Criteria::Chain do
  let(:time) { DateTime.now }
  let!(:user) { User.create(name: 'Josh', email: 'josh@joshsymonds.com', password: 'Test123') }
  let(:chain) { described_class.new(User) }

  describe 'Query vs Scan' do
    it 'Scans when query is empty' do
      chain = described_class.new(Address)
      chain = chain.where({})
      expect(chain).to receive(:raw_pages_via_scan).and_return([])
      chain.all
    end

    it 'Queries when query is only ID' do
      chain = described_class.new(Address)
      chain = chain.where(id: 'test')
      expect(chain).to receive(:raw_pages_via_query).and_return([])
      chain.all
    end

    it 'Queries when query contains ID' do
      chain = described_class.new(Address)
      chain = chain.where(id: 'test', city: 'Bucharest')
      expect(chain).to receive(:raw_pages_via_query).and_return([])
      chain.all
    end

    it 'Scans when query includes keys that are neither a hash nor a range' do
      chain = described_class.new(Address)
      chain = chain.where(city: 'Bucharest')
      expect(chain).to receive(:raw_pages_via_scan).and_return([])
      chain.all
    end

    it 'Scans when query is only a range' do
      chain = described_class.new(Tweet)
      chain = chain.where(group: 'xx')
      expect(chain).to receive(:raw_pages_via_scan).and_return([])
      chain.all
    end

    it 'Scans when there is only not-equal operator for hash key' do
      chain = described_class.new(Address)
      chain = chain.where('id.in': ['test'])
      expect(chain).to receive(:raw_pages_via_scan).and_return([])
      chain.all
    end
  end

  describe 'Limits' do
    shared_examples 'correct handling chain limits' do |request_type|
      let(:model) do
        new_class do
          range :age, :integer
          field :name
        end
      end

      before do
        @request_type = request_type
        (1..10).each do |i|
          model.create(id: '1', name: 'Josh', age: i)
          model.create(id: '1', name: 'Pascal', age: i + 100)
        end
      end

      def request_params
        return { id: '1' } if @request_type == :query

        {}
      end

      it 'supports record_limit' do
        expect(model.where(request_params.merge(name: 'Josh')).record_limit(1).count).to eq(1)
        expect(model.where(request_params.merge(name: 'Josh')).record_limit(3).count).to eq(3)
      end

      it 'supports scan_limit' do
        expect(model.where(request_params.merge(name: 'Pascal')).scan_limit(1).count).to eq(0)
        expect(model.where(request_params.merge(name: 'Pascal')).scan_limit(11).count).to eq(1)
      end

      it 'supports batch' do
        expect(model.where(request_params.merge(name: 'Josh')).batch(1).count).to eq(10)
        expect(model.where(request_params.merge(name: 'Josh')).batch(3).count).to eq(10)
      end

      it 'supports combined limits with batch size 1' do
        # Scanning through 13 means it'll see 10 Josh objects and then
        # 3 Pascal objects but it'll hit record_limit first with 2 objects
        # so we'd only see 12 requests due to batching.
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(12).times.and_call_original
        expect(model.where(request_params.merge(name: 'Pascal'))
                    .record_limit(2)
                    .scan_limit(13)
                    .batch(1).count).to eq(2)
      end

      it 'supports combined limits with batch size other than 1' do
        # Querying in batches of 3 so we'd see:
        # 3 Josh, 3 Josh, 3 Josh, 1 Josh + 2 Pascal, 3 Pascal, 3 Pascal, 2 Pascal
        # So total of 7 requests
        expect(Dynamoid.adapter.client).to receive(request_type).exactly(7).times.and_call_original
        expect(model.where(request_params.merge(name: 'Pascal'))
                    .record_limit(10)
                    .batch(3).count).to eq(10)
      end
    end

    describe 'Query' do
      it_behaves_like 'correct handling chain limits', :query
    end

    describe 'Scan' do
      it_behaves_like 'correct handling chain limits', :scan
    end
  end

  describe 'Query with keys conditions' do
    let(:model) do
      new_class(partition_key: :name) do
        range :age, :integer
      end
    end

    it 'supports eq' do
      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 30)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', age: 10).all).to contain_exactly(customer1)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:age)
      expect(chain.key_fields_detector.index_name).to be_nil
    end

    it 'supports lt' do
      customer1 = model.create(name: 'Bob', age: 5)
      customer2 = model.create(name: 'Bob', age: 9)
      customer3 = model.create(name: 'Bob', age: 12)

      expect(model.where(name: 'Bob', 'age.lt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gt' do
      customer1 = model.create(name: 'Bob', age: 11)
      customer2 = model.create(name: 'Bob', age: 12)
      customer3 = model.create(name: 'Bob', age: 9)

      expect(model.where(name: 'Bob', 'age.gt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports lte' do
      customer1 = model.create(name: 'Bob', age: 5)
      customer2 = model.create(name: 'Bob', age: 9)
      customer3 = model.create(name: 'Bob', age: 12)

      expect(model.where(name: 'Bob', 'age.lte': 9).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gte' do
      customer1 = model.create(name: 'Bob', age: 11)
      customer2 = model.create(name: 'Bob', age: 12)
      customer3 = model.create(name: 'Bob', age: 9)

      expect(model.where(name: 'Bob', 'age.gte': 11).all).to contain_exactly(customer1, customer2)
    end

    it 'supports begins_with' do
      model = new_class(partition_key: :name) do
        range :job_title
      end

      customer1 = model.create(name: 'Bob', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'Bob', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'Bob', job_title: 'Creative Consultant')

      expect(model.where(name: 'Bob', 'job_title.begins_with': 'Environmental').all)
        .to contain_exactly(customer1, customer2)
    end

    it 'supports between' do
      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 20)
      customer3 = model.create(name: 'Bob', age: 30)
      customer4 = model.create(name: 'Bob', age: 40)

      expect(model.where(name: 'Bob', 'age.between': [19, 31]).all).to contain_exactly(customer2, customer3)
    end

    it 'supports multiple conditions for the same attribute' do
      skip 'Aws::DynamoDB::Errors::ValidationException: KeyConditionExpressions must only contain one condition per key'

      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 20)
      customer3 = model.create(name: 'Bob', age: 30)
      customer4 = model.create(name: 'Bob', age: 40)

      expect(model.where(name: 'Bob', 'age.gt': 19).where('age.lt': 31).all).to contain_exactly(customer2, customer3)
    end

    it 'supports multiple conditions for the same attribute with the same operator' do
      skip 'Aws::DynamoDB::Errors::ValidationException: KeyConditionExpressions must only contain one condition per key'

      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 20)
      customer3 = model.create(name: 'Bob', age: 30)
      customer4 = model.create(name: 'Bob', age: 40)

      expect(model.where(name: 'Bob', 'age.gt': 31).where('age.gt': 19).all).to contain_exactly(customer4)
    end

    it 'allows conditions with attribute names conflicting with DynamoDB reserved words' do
      model = new_class do
        range :size # SIZE is reserved word
      end

      model.create_table
      put_attributes(model.table_name, id: '1', size: 'c')

      documents = model.where(id: '1', size: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names containing special characters' do
      model = new_class do
        range :'sort:key'
      end

      model.create_table
      put_attributes(model.table_name, id: '1', 'sort:key': 'c')

      documents = model.where(id: '1', 'sort:key': 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names starting with _' do
      model = new_class do
        range :_sortKey
      end

      model.create_table
      put_attributes(model.table_name, id: '1', _sortKey: 'c')

      documents = model.where(id: '1', _sortKey: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'raises error when operator is not supported' do
      expect do
        model.where(name: 'Bob', 'age.foo': 10).to_a
      end.to raise_error(Dynamoid::Errors::Error, 'Unsupported operator foo in age.foo')
    end

    context 'primary key dumping' do
      it 'uses dumped value of partition key to query item' do
        klass = new_class(partition_key: { name: :published_on, type: :date })

        obj1 = klass.create(published_on: Date.today + 1)
        obj2 = klass.create(published_on: Date.today + 2)

        chain = described_class.new(klass)
        expect(chain).to receive(:raw_pages_via_query).and_call_original

        objects_found = chain.where(published_on: obj1.published_on).all
        expect(objects_found).to contain_exactly(obj1)
      end

      it 'uses dumped value of sort key to query item' do
        klass = new_class do
          range :published_on, :date
        end

        obj1 = klass.create(published_on: Date.today + 1)
        obj2 = klass.create(published_on: Date.today + 2)

        chain = described_class.new(klass)
        expect(chain).to receive(:raw_pages_via_query).and_call_original

        objects_found = chain.where(id: obj1.id, published_on: obj1.published_on).all
        expect(objects_found).to contain_exactly(obj1)
      end
    end
  end

  # http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LegacyConditionalParameters.QueryFilter.html
  describe 'Query with non-keys conditions' do
    let(:model) do
      new_class do
        table name: :customer, key: :name
        range :last_name
        field :age, :integer
      end
    end

    it 'supports eq' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 30)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'a', age: 10).all).to contain_exactly(customer1)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to be_nil
      expect(chain.key_fields_detector.index_name).to be_nil
    end

    it 'supports eq for set' do
      klass = new_class do
        range :last_name
        field :set, :set
      end

      document1 = klass.create(id: '1', last_name: 'a', set: [1, 2].to_set)
      document2 = klass.create(id: '1', last_name: 'b', set: [3, 4].to_set)

      chain = described_class.new(klass)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(id: '1', set: [1, 2].to_set).all).to contain_exactly(document1)
    end

    it 'supports eq for array' do
      klass = new_class do
        range :last_name
        field :array, :array
      end

      document1 = klass.create(id: '1', last_name: 'a', array: [1, 2])
      document2 = klass.create(id: '1', last_name: 'b', array: [3, 4])

      chain = described_class.new(klass)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(id: '1', array: [1, 2]).all).to contain_exactly(document1)
    end

    it 'supports ne' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 5)
      customer2 = model.create(name: 'a', last_name: 'b', age: 9)

      expect(model.where(name: 'a', 'age.ne': 9).all).to contain_exactly(customer1)
    end

    it 'supports lt' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 5)
      customer2 = model.create(name: 'a', last_name: 'b', age: 9)
      customer3 = model.create(name: 'a', last_name: 'c', age: 12)

      expect(model.where(name: 'a', 'age.lt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gt' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 11)
      customer2 = model.create(name: 'a', last_name: 'b', age: 12)
      customer3 = model.create(name: 'a', last_name: 'c', age: 9)

      expect(model.where(name: 'a', 'age.gt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports lte' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 5)
      customer2 = model.create(name: 'a', last_name: 'b', age: 9)
      customer3 = model.create(name: 'a', last_name: 'c', age: 12)

      expect(model.where(name: 'a', 'age.lte': 9).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gte' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 11)
      customer2 = model.create(name: 'a', last_name: 'b', age: 12)
      customer3 = model.create(name: 'a', last_name: 'c', age: 9)

      expect(model.where(name: 'a', 'age.gte': 11).all).to contain_exactly(customer1, customer2)
    end

    it 'supports begins_with' do
      model = new_class(partition_key: :name) do
        range :last_name
        field :job_title
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.begins_with': 'Environmental').all)
        .to contain_exactly(customer1, customer2)
    end

    it 'supports between' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)
      customer4 = model.create(name: 'a', last_name: 'd', age: 40)

      expect(model.where(name: 'a', 'age.between': [19, 31]).all).to contain_exactly(customer2, customer3)
    end

    it 'supports in' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)

      expect(model.where(name: 'a', 'age.in': [10, 20]).all).to contain_exactly(customer1, customer2)
    end

    it 'supports contains' do
      model = new_class(partition_key: :name) do
        range :last_name
        field :job_title, :string
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.contains': 'Consul').all)
        .to contain_exactly(customer1, customer3)
    end

    it 'supports not_contains' do
      model = new_class(partition_key: :name) do
        range :last_name
        field :job_title, :string
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.not_contains': 'Consul').all)
        .to contain_exactly(customer2)
    end

    it 'supports null' do
      model.create_table

      put_attributes(model.table_name, name: 'a', last_name: 'aa', age: 1)
      put_attributes(model.table_name, name: 'a', last_name: 'bb', age: 2)
      put_attributes(model.table_name, name: 'a', last_name: 'cc',)

      documents = model.where(name: 'a', 'age.null': true).to_a
      expect(documents.map(&:last_name)).to contain_exactly('cc')

      documents = model.where(name: 'a', 'age.null': false).to_a
      expect(documents.map(&:last_name)).to contain_exactly('aa', 'bb')
    end

    it 'supports not_null' do
      model.create_table

      put_attributes(model.table_name, name: 'a', last_name: 'aa', age: 1)
      put_attributes(model.table_name, name: 'a', last_name: 'bb', age: 2)
      put_attributes(model.table_name, name: 'a', last_name: 'cc',)

      documents = model.where(name: 'a', 'age.not_null': true).to_a
      expect(documents.map(&:last_name)).to contain_exactly('aa', 'bb')

      documents = model.where('age.not_null': false).to_a
      expect(documents.map(&:last_name)).to contain_exactly('cc')
    end

    it 'supports multiple conditions for the same attribute' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)
      customer4 = model.create(name: 'a', last_name: 'd', age: 40)

      expect(model.where(name: 'a', 'age.gt': 19, 'age.lt': 31).all).to contain_exactly(customer2, customer3)
    end

    it 'supports multiple conditions for the same attribute with the same operator' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)
      customer4 = model.create(name: 'a', last_name: 'd', age: 40)

      expect(model.where(name: 'a', 'age.gt': 31).where('age.gt': 19).all).to contain_exactly(customer4)
    end

    it 'allows conditions with attribute names conflicting with DynamoDB reserved words' do
      model = new_class do
        # SCAN, SET and SIZE are reserved words
        field :scan
        field :set
        field :size
      end

      model.create_table
      put_attributes(model.table_name, id: '1', scan: 'a', set: 'b', size: 'c')

      documents = model.where(id: '1', scan: 'a', set: 'b', size: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names containing special characters' do
      model = new_class do
        field :'last:name'
      end

      model.create_table
      put_attributes(model.table_name, id: '1', 'last:name': 'c')

      documents = model.where(id: '1', 'last:name': 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names starting with _' do
      model = new_class do
        field :_lastName
      end

      model.create_table
      put_attributes(model.table_name, id: '1', _lastName: 'c')

      documents = model.where(id: '1', _lastName: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'raises error when operator is not supported' do
      expect do
        model.where(name: 'a', 'age.foo': 9).to_a
      end.to raise_error(Dynamoid::Errors::Error, 'Unsupported operator foo in age.foo')
    end
  end

  # http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LegacyConditionalParameters.ScanFilter.html
  describe 'Scan conditions' do
    let(:model) do
      new_class do
        field :age, :integer
        field :job_title, :string
      end
    end

    it 'supports eq' do
      customer1 = model.create(age: 10)
      customer2 = model.create(age: 30)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_scan).and_call_original
      expect(chain.where(age: 10).all).to contain_exactly(customer1)
      expect(chain.key_fields_detector.hash_key).to be_nil
      expect(chain.key_fields_detector.range_key).to be_nil
      expect(chain.key_fields_detector.index_name).to be_nil
    end

    it 'supports eq for set' do
      klass = new_class do
        field :set, :set
      end
      document1 = klass.create(set: %w[a b])
      document2 = klass.create(set: %w[b c])

      expect(klass.where(set: %w[a b].to_set).all).to contain_exactly(document1)
    end

    it 'supports eq for array' do
      klass = new_class do
        field :array, :array
      end
      document1 = klass.create(array: %w[a b])
      document2 = klass.create(array: %w[b c])

      expect(klass.where(array: %w[a b]).all).to contain_exactly(document1)
    end

    it 'supports ne' do
      customer1 = model.create(age: 5)
      customer2 = model.create(age: 9)

      expect(model.where('age.ne': 9).all).to contain_exactly(customer1)
    end

    it 'supports lt' do
      customer1 = model.create(age: 5)
      customer2 = model.create(age: 9)
      customer3 = model.create(age: 12)

      expect(model.where('age.lt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gt' do
      customer1 = model.create(age: 11)
      customer2 = model.create(age: 12)
      customer3 = model.create(age: 9)

      expect(model.where('age.gt': 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports lte' do
      customer1 = model.create(age: 5)
      customer2 = model.create(age: 9)
      customer3 = model.create(age: 12)

      expect(model.where('age.lte': 9).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gte' do
      customer1 = model.create(age: 11)
      customer2 = model.create(age: 12)
      customer3 = model.create(age: 9)

      expect(model.where('age.gte': 11).all).to contain_exactly(customer1, customer2)
    end

    it 'supports begins_with' do
      customer1 = model.create(job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(job_title: 'Environmental Project Manager')
      customer3 = model.create(job_title: 'Creative Consultant')

      expect(model.where('job_title.begins_with': 'Environmental').all)
        .to contain_exactly(customer1, customer2)
    end

    it 'supports between' do
      customer1 = model.create(age: 10)
      customer2 = model.create(age: 20)
      customer3 = model.create(age: 30)
      customer4 = model.create(age: 40)

      expect(model.where('age.between': [19, 31]).all).to contain_exactly(customer2, customer3)
    end

    it 'supports in' do
      customer1 = model.create(age: 10)
      customer2 = model.create(age: 20)
      customer3 = model.create(age: 30)

      expect(model.where('age.in': [10, 20]).all).to contain_exactly(customer1, customer2)
    end

    it 'supports contains' do
      customer1 = model.create(job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(job_title: 'Environmental Project Manager')
      customer3 = model.create(job_title: 'Creative Consultant')

      expect(model.where('job_title.contains': 'Consul').all)
        .to contain_exactly(customer1, customer3)
    end

    it 'supports contains for set' do
      klass = new_class do
        field :set, :set
      end
      document1 = klass.create(set: %w[a b])
      document2 = klass.create(set: %w[b c])

      expect(klass.where('set.contains': 'a').all).to contain_exactly(document1)
      expect(klass.where('set.contains': 'b').all).to contain_exactly(document1, document2)
      expect(klass.where('set.contains': 'c').all).to contain_exactly(document2)
    end

    it 'supports contains for array' do
      klass = new_class do
        field :array, :array
      end
      document1 = klass.create(array: %w[a b])
      document2 = klass.create(array: %w[b c])

      expect(klass.where('array.contains': 'a').all).to contain_exactly(document1)
      expect(klass.where('array.contains': 'b').all).to contain_exactly(document1, document2)
      expect(klass.where('array.contains': 'c').all).to contain_exactly(document2)
    end

    it 'supports not_contains' do
      customer1 = model.create(job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(job_title: 'Environmental Project Manager')
      customer3 = model.create(job_title: 'Creative Consultant')

      expect(model.where('job_title.not_contains': 'Consul').all)
        .to contain_exactly(customer2)
    end

    it 'supports null' do
      model.create_table

      put_attributes(model.table_name, id: '1', age: 1)
      put_attributes(model.table_name, id: '2', age: 2)
      put_attributes(model.table_name, id: '3')

      documents = model.where('age.null': true).to_a
      expect(documents.map(&:id)).to contain_exactly('3')

      documents = model.where('age.null': false).to_a
      expect(documents.map(&:id)).to contain_exactly('1', '2')
    end

    it 'supports not_null' do
      model.create_table

      put_attributes(model.table_name, id: '1', age: 1)
      put_attributes(model.table_name, id: '2', age: 2)
      put_attributes(model.table_name, id: '3')

      documents = model.where('age.not_null': true).to_a
      expect(documents.map(&:id)).to contain_exactly('1', '2')

      documents = model.where('age.not_null': false).to_a
      expect(documents.map(&:id)).to contain_exactly('3')
    end

    it 'supports multiple conditions for the same attribute' do
      customer1 = model.create(age: 10)
      customer2 = model.create(age: 20)
      customer3 = model.create(age: 30)
      customer4 = model.create(age: 40)

      expect(model.where('age.gt': 19, 'age.lt': 31).all).to contain_exactly(customer2, customer3)
    end

    it 'supports multiple conditions for the same attribute with the same operator' do
      customer1 = model.create(age: 10)
      customer2 = model.create(age: 20)
      customer3 = model.create(age: 30)
      customer4 = model.create(age: 40)

      expect(model.where('age.gt': 31).where('age.gt': 19).all.to_a).to eq([customer4])
    end

    it 'allows conditions with attribute names conflicting with DynamoDB reserved words' do
      model = new_class do
        # SCAN, SET and SIZE are reserved words
        field :scan
        field :set
        field :size
      end

      model.create_table
      put_attributes(model.table_name, id: '1', scan: 'a', set: 'b', size: 'c')

      documents = model.where(scan: 'a', set: 'b', size: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names containing special characters' do
      model = new_class do
        field :'last:name'
      end

      model.create_table
      put_attributes(model.table_name, id: '1', 'last:name': 'c')

      documents = model.where('last:name': 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'allows conditions with attribute names starting with _' do
      model = new_class do
        field :_lastName
      end

      model.create_table
      put_attributes(model.table_name, id: '1', _lastName: 'c')

      documents = model.where(_lastName: 'c').to_a
      expect(documents.map(&:id)).to eql ['1']
    end

    it 'raises error when operator is not supported' do
      expect do
        model.where('age.foo': 9).to_a
      end.to raise_error(Dynamoid::Errors::Error, 'Unsupported operator foo in age.foo')
    end
  end

  describe 'Lazy loading' do
    describe '.all' do
      it 'does load result lazily' do
        Vehicle.create

        expect(Dynamoid.adapter.client).to receive(:scan).exactly(0).times.and_call_original
        Vehicle.record_limit(1).all
      end
    end

    describe '.find_by_pages' do
      it 'does load result lazily' do
        Vehicle.create

        expect(Dynamoid.adapter.client).to receive(:scan).exactly(0).times.and_call_original
        Vehicle.record_limit(1).find_by_pages
      end
    end
  end

  describe 'local secondary indexes used for `where` clauses' do
    let(:model) do
      new_class(partition_key: :name) do
        range :range, :integer

        field :range2, :integer
        field :range3, :integer

        local_secondary_index range_key: :range2, name: :range2index
        local_secondary_index range_key: :range3, name: :range3index
      end
    end

    before do
      @customer1 = model.create(name: 'Bob', range: 1, range2: 11, range3: 111)
      @customer2 = model.create(name: 'Bob', range: 2, range2: 22, range3: 222)
      @customer3 = model.create(name: 'Bob', range: 3, range2: 33, range3: 333)
    end

    it 'supports query on local secondary index but always defaults to table range key' do
      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', 'range.lt': 3, 'range2.gt': 15).to_a.size).to eq(1)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:range)
      expect(chain.key_fields_detector.index_name).to be_nil
    end

    it 'supports query on local secondary index' do
      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', 'range2.gt': 15).to_a.size).to eq(2)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:range2)
      expect(chain.key_fields_detector.index_name).to eq(:range2index)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', 'range3.lt': 200).to_a.size).to eq(1)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:range3)
      expect(chain.key_fields_detector.index_name).to eq(:range3index)
    end

    it 'supports query on local secondary index with start' do
      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', 'range2.gt': 15).to_a.size).to eq(2)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:range2)
      expect(chain.key_fields_detector.index_name).to eq(:range2index)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(name: 'Bob', 'range2.gt': 15).start(@customer2).all).to contain_exactly(@customer3)
      expect(chain.key_fields_detector.hash_key).to eq(:name)
      expect(chain.key_fields_detector.range_key).to eq(:range2)
      expect(chain.key_fields_detector.index_name).to eq(:range2index)
    end
  end

  describe 'global secondary indexes used for `where` clauses' do
    it 'does not use global secondary index if does not project all attributes' do
      model = new_class(partition_key: :name) do
        range :customerid, :integer

        field :city
        field :age, :integer
        field :gender

        global_secondary_index hash_key: :city, range_key: :age, name: :cityage
      end

      customer1 = model.create(name: 'Bob', city: 'San Francisco', age: 10, gender: 'male', customerid: 1)
      customer2 = model.create(name: 'Jeff', city: 'San Francisco', age: 15, gender: 'male', customerid: 2)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_scan).and_call_original
      expect(chain.where(city: 'San Francisco').to_a.size).to eq(2)
      # Does not use GSI since not projecting all attributes
      expect(chain.key_fields_detector.hash_key).to be_nil
      expect(chain.key_fields_detector.range_key).to be_nil
      expect(chain.key_fields_detector.index_name).to be_nil
    end

    context 'with full composite key for table' do
      let(:model) do
        new_class(partition_key: :name) do
          range :customerid, :integer

          field :city
          field :email
          field :age, :integer
          field :gender

          global_secondary_index hash_key: :city, range_key: :age, name: :cityage, projected_attributes: :all
          global_secondary_index hash_key: :city, range_key: :gender, name: :citygender, projected_attributes: :all
          global_secondary_index hash_key: :email, range_key: :age, name: :emailage, projected_attributes: :all
          global_secondary_index hash_key: :name, range_key: :age, name: :nameage, projected_attributes: :all
        end
      end

      before do
        @customer1 = model.create(name: 'Bob', city: 'San Francisco', email: 'bob@test.com', age: 10, gender: 'male',
                                  customerid: 1)
        @customer2 = model.create(name: 'Jeff', city: 'San Francisco', email: 'jeff@test.com', age: 15, gender: 'male',
                                  customerid: 2)
        @customer3 = model.create(name: 'Mark', city: 'San Francisco', email: 'mark@test.com', age: 20, gender: 'male',
                                  customerid: 3)
        @customer4 = model.create(name: 'Greg', city: 'New York', email: 'greg@test.com', age: 25, gender: 'male',
                                  customerid: 4)
      end

      it 'supports query on global secondary index but always defaults to table hash key' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(name: 'Bob').to_a.size).to eq(1)
        expect(chain.key_fields_detector.hash_key).to eq(:name)
        expect(chain.key_fields_detector.range_key).to be_nil
        expect(chain.key_fields_detector.index_name).to be_nil
      end

      it 'supports query on global secondary index' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco').to_a.size).to eq(3)
        expect(chain.key_fields_detector.hash_key).to eq(:city)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:cityage)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco', 'age.gt': 12).to_a.size).to eq(2)
        expect(chain.key_fields_detector.hash_key).to eq(:city)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:cityage)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(email: 'greg@test.com').to_a.size).to eq(1)
        expect(chain.key_fields_detector.hash_key).to eq(:email)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:emailage)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(email: 'greg@test.com', 'age.gt': 12).to_a.size).to eq(1)
        expect(chain.key_fields_detector.hash_key).to eq(:email)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:emailage)
      end

      it 'supports scan when no global secondary index available' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_scan).and_call_original
        expect(chain.where(gender: 'male').to_a.size).to eq(4)
        expect(chain.key_fields_detector.hash_key).to be_nil
        expect(chain.key_fields_detector.range_key).to be_nil
        expect(chain.key_fields_detector.index_name).to be_nil
      end

      it 'supports query on global secondary index with start' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco').to_a.size).to eq(3)
        expect(chain.key_fields_detector.hash_key).to eq(:city)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:cityage)

        # Now query with start at customer2 and we should only see customer3
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco').start(@customer2).all).to contain_exactly(@customer3)
      end

      it "does not use index if a condition for index hash key is other than 'equal'" do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_scan).and_call_original
        expect(chain.where('city.begins_with': 'San').to_a.size).to eq(3)
        expect(chain.key_fields_detector.hash_key).to be_nil
        expect(chain.key_fields_detector.range_key).to be_nil
        expect(chain.key_fields_detector.index_name).to be_nil
      end

      it 'prefers global secondary index with range key used in conditions to index w/o such range key' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco', 'age.lte': 15).to_a.size).to eq(2)
        expect(chain.key_fields_detector.hash_key).to eq(:city)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:cityage)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(city: 'San Francisco', gender: 'male').to_a.size).to eq(3)
        expect(chain.key_fields_detector.hash_key).to eq(:city)
        expect(chain.key_fields_detector.range_key).to eq(:gender)
        expect(chain.key_fields_detector.index_name).to eq(:citygender)
      end

      it 'uses global secondary index when secondary hash key overlaps with primary hash key and range key matches' do
        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original
        expect(chain.where(name: 'Bob', age: 10).to_a.size).to eq(1)
        expect(chain.key_fields_detector.hash_key).to eq(:name)
        expect(chain.key_fields_detector.range_key).to eq(:age)
        expect(chain.key_fields_detector.index_name).to eq(:nameage)
      end
    end

    it 'supports query on global secondary index with correct start key without table range key' do
      model = new_class(partition_key: :name) do
        field :city
        field :age, :integer

        global_secondary_index hash_key: :city, range_key: :age, name: :cityage, projected_attributes: :all
      end

      customer1 = model.create(name: 'Bob', city: 'San Francisco', age: 10)
      customer2 = model.create(name: 'Jeff', city: 'San Francisco', age: 15)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original
      expect(chain.where(city: 'San Francisco').start(customer1).all).to contain_exactly(customer2)
    end
  end

  describe 'type casting in `where` clause' do
    let(:klass) do
      new_class do
        field :count, :integer
      end
    end

    it 'type casts condition values' do
      obj1 = klass.create(count: 1)
      obj2 = klass.create(count: 2)

      expect(klass.where(count: '1').all.to_a).to eql([obj1])
    end

    it 'type casts condition values with predicates' do
      obj1 = klass.create(count: 1)
      obj2 = klass.create(count: 2)
      obj3 = klass.create(count: 3)

      expect(klass.where('count.gt': '1').all).to contain_exactly(obj2, obj3)
    end

    it 'type casts collection of condition values' do
      obj1 = klass.create(count: 1)
      obj2 = klass.create(count: 2)
      obj3 = klass.create(count: 3)

      expect(klass.where('count.in': %w[1 2]).all).to contain_exactly(obj1, obj2)
    end
  end

  describe 'dumping in `where` clause' do
    it 'dumps datetime' do
      model = new_class do
        field :activated_at, :datetime
      end

      customer1 = model.create(activated_at: Time.now)
      customer2 = model.create(activated_at: Time.now - 1.hour)
      customer3 = model.create(activated_at: Time.now - 2.hour)

      expect(
        model.where('activated_at.gt': Time.now - 1.5.hours).all
      ).to contain_exactly(customer1, customer2)
    end

    it 'dumps date' do
      model = new_class do
        field :registered_on, :date
      end

      customer1 = model.create(registered_on: Date.today)
      customer2 = model.create(registered_on: Date.today - 2.day)
      customer3 = model.create(registered_on: Date.today - 4.days)

      expect(
        model.where('registered_on.gt': Date.today - 3.days).all
      ).to contain_exactly(customer1, customer2)
    end

    it 'dumps array elements' do
      model = new_class do
        field :birthday, :date
      end

      customer1 = model.create(birthday: '1978-08-21'.to_date)
      customer2 = model.create(birthday: '1984-05-13'.to_date)
      customer3 = model.create(birthday: '1991-11-28'.to_date)

      expect(
        model.where('birthday.between': ['1980-01-01'.to_date, '1990-01-01'.to_date]).all
      ).to contain_exactly(customer2)
    end

    context 'Query' do
      it 'dumps partition key `equal` condition' do
        model = new_class(partition_key: { name: :registered_on, type: :date })

        customer1 = model.create(registered_on: Date.today)
        customer2 = model.create(registered_on: Date.today - 2.day)

        expect(
          model.where(registered_on: Date.today).all
        ).to contain_exactly(customer1)
      end

      it 'dumps sort key `equal` condition' do
        model = new_class(partition_key: :first_name) do
          range :registered_on, :date
        end

        customer1 = model.create(first_name: 'Alice', registered_on: Date.today)
        customer2 = model.create(first_name: 'Alice', registered_on: Date.today - 2.day)

        expect(
          model.where(first_name: 'Alice', registered_on: Date.today).all
        ).to contain_exactly(customer1)
      end

      it 'dumps sort key `range` condition' do
        model = new_class(partition_key: :first_name) do
          range :registered_on, :date
        end

        customer1 = model.create(first_name: 'Alice', registered_on: Date.today)
        customer2 = model.create(first_name: 'Alice', registered_on: Date.today - 2.day)
        customer3 = model.create(first_name: 'Alice', registered_on: Date.today - 4.days)

        expect(
          model.where(first_name: 'Alice', 'registered_on.gt': Date.today - 3.days).all
        ).to contain_exactly(customer1, customer2)
      end

      it 'dumps non-key field `equal` condition' do
        model = new_class(partition_key: :first_name) do
          range :last_name
          field :registered_on, :date # <==== not range key
        end

        customer1 = model.create(first_name: 'Alice', last_name: 'Cooper', registered_on: Date.today)
        customer2 = model.create(first_name: 'Alice', last_name: 'Morgan', registered_on: Date.today - 2.day)

        expect(
          model.where(first_name: 'Alice', registered_on: Date.today).all
        ).to contain_exactly(customer1)
      end

      it 'dumps non-key field `range` condition' do
        model = new_class(partition_key: :first_name) do
          range :last_name
          field :registered_on, :date # <==== not range key
        end

        customer1 = model.create(first_name: 'Alice', last_name: 'Cooper', registered_on: Date.today)
        customer2 = model.create(first_name: 'Alice', last_name: 'Morgan', registered_on: Date.today - 2.day)
        customer3 = model.create(first_name: 'Alice', last_name: 'Smit',   registered_on: Date.today - 4.days)

        expect(
          model.where(first_name: 'Alice', 'registered_on.gt': Date.today - 3.days).all
        ).to contain_exactly(customer1, customer2)
      end
    end

    context 'Scan' do
      it 'dumps field for `equal` condition' do
        model = new_class do
          field :birthday, :date
        end

        customer1 = model.create(birthday: '1978-08-21'.to_date)
        customer2 = model.create(birthday: '1984-05-13'.to_date)

        expect(model.where(birthday: '1978-08-21').all).to contain_exactly(customer1)
      end

      it 'dumps field for `range` condition' do
        model = new_class do
          field :birthday, :date
        end

        customer1 = model.create(birthday: '1978-08-21'.to_date)
        customer2 = model.create(birthday: '1984-05-13'.to_date)

        expect(model.where('birthday.gt': '1980-01-01').all).to contain_exactly(customer2)
      end
    end
  end

  context 'field is not declared in document' do
    context 'Query' do
      let(:class_with_not_declared_field) do
        new_class do
          field :name
        end
      end

      before do
        class_with_not_declared_field.create_table
      end

      it 'ignores it without exceptions' do
        Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', name: 'Mike', bod: '1996-12-21')
        objects = class_with_not_declared_field.where(id: '1', name: 'Mike').to_a

        expect(objects.map(&:id)).to eql(['1'])
      end
    end

    context 'Scan' do
      let(:class_with_not_declared_field) do
        new_class do
          range :name
        end
      end

      before do
        class_with_not_declared_field.create_table
      end

      it 'ignores it without exceptions' do
        Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', name: 'Mike', bod: '1996-12-21')
        objects = class_with_not_declared_field.where(id: '1', name: 'Mike').to_a

        expect(objects.map(&:id)).to eql(['1'])
      end
    end
  end

  describe '#where' do
    context 'passed condition for nonexistent attribute' do
      let(:model) do
        new_class do
          field :city
        end
      end

      before do
        model.create_table
      end

      it 'writes warning message' do
        expect(Dynamoid.logger).to receive(:warn)
          .with('where conditions contain nonexistent field name `town`')

        model.where(town: 'New York')
      end

      it 'writes warning message for condition with operator' do
        expect(Dynamoid.logger).to receive(:warn)
          .with('where conditions contain nonexistent field name `town`')

        model.where('town.contain': 'New York')
      end

      it 'writes warning message with a list of attributes' do
        expect(Dynamoid.logger).to receive(:warn)
          .with('where conditions contain nonexistent field names `town`, `street1`')

        model.where(town: 'New York', street1: 'Allen Street')
      end
    end

    context 'nil check' do
      let(:model) do
        new_class do
          field :name
        end
      end

      before do
        @mike = model.create(name: 'Mike')
        @johndoe = model.create(name: nil)
      end

      context 'store_attribute_with_nil_value = true', config: { store_attribute_with_nil_value: true } do
        it 'supports "eq nil" check' do
          expect(model.where(name: nil).to_a).to eq [@johndoe]
        end

        it 'supports "in [nil]" check' do
          expect(model.where('name.in': [nil]).to_a).to eq [@johndoe]
        end

        it 'supports "ne nil" check' do
          expect(model.where('name.ne': nil).to_a).to eq [@mike]
        end
      end

      context 'store_attribute_with_nil_value = false', config: { store_attribute_with_nil_value: false } do
        it 'supports "null" check' do
          expect(model.where('name.null': true).to_a).to eq [@johndoe]
          expect(model.where('name.null': false).to_a).to eq [@mike]
        end

        it 'supports "not_null" check' do
          expect(model.where('name.not_null': true).to_a).to eq [@mike]
          expect(model.where('name.not_null': false).to_a).to eq [@johndoe]
        end

        it 'does not support "eq nil" check' do
          expect(model.where(name: nil).to_a).to eq []
        end

        it 'does not supports "in [nil]" check' do
          expect(model.where('name.in': [nil]).to_a).to eq []
        end

        it 'does not support "ne nil" check' do
          expect(model.where('name.ne': nil).to_a).to contain_exactly(@mike, @johndoe)
        end
      end
    end

    # Regression
    # https://github.com/Dynamoid/dynamoid/issues/435
    context 'when inheritance field (:type by default) is a GSI hash key' do
      it 'works without exception' do
        # rubocop:disable Lint/ConstantDefinitionInBlock
        UserWithGSI = new_class class_name: 'UserWithGSI' do
          field :type

          global_secondary_index hash_key: :type,
                                 range_key: :created_at,
                                 projected_attributes: :all
        end
        # rubocop:enable Lint/ConstantDefinitionInBlock

        obj = UserWithGSI.create

        actual = UserWithGSI.where(type: 'UserWithGSI').all.to_a
        expect(actual).to eq [obj]
      end
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          field :name
          after_initialize { print 'run after_initialize' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect { klass_with_callback.where(name: 'Alex').to_a }.to output('run after_initialize').to_stdout
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          field :name
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect { klass_with_callback.where(name: 'Alex').to_a }.to output('run after_find').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          field :name
          after_initialize { print 'run after_initialize' }
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect do
          klass_with_callback.where(name: 'Alex').to_a
        end.to output('run after_initializerun after_find').to_stdout
      end
    end
  end

  describe '#where with String query' do
    let(:klass) do
      new_class do
        field :first_name # `name` is a reserved keyword
        field :age, :integer
      end
    end

    it 'filters by specified conditions' do
      obj1 = klass.create!(first_name: 'Alex', age: 42)
      obj2 = klass.create!(first_name: 'Michael', age: 50)

      expect(klass.where('age > :age', age: 42).all).to contain_exactly(obj2)
      expect(klass.where('first_name = :name', name: 'Alex').all).to contain_exactly(obj1)
    end

    it 'accepts placeholder names with ":" prefix' do
      obj1 = klass.create!(first_name: 'Alex', age: 42)
      obj2 = klass.create!(first_name: 'Michael', age: 50)

      expect(klass.where('age > :age', ':age': 42).all).to contain_exactly(obj2)
      expect(klass.where('first_name = :name', ':name': 'Alex').all).to contain_exactly(obj1)
    end

    it 'combines with a call with String query with logical AND' do
      obj1 = klass.create!(first_name: 'Alex', age: 42)
      obj2 = klass.create!(first_name: 'Michael', age: 50)
      obj3 = klass.create!(first_name: 'Alex', age: 18)

      expect(klass.where('age < :age', age: 40).where('first_name = :name', name: 'Alex').all).to contain_exactly(obj3)
    end

    it 'combines with a call with Hash query with logical AND' do
      obj1 = klass.create!(first_name: 'Alex', age: 42)
      obj2 = klass.create!(first_name: 'Michael', age: 50)
      obj3 = klass.create!(first_name: 'Alex', age: 18)

      expect(klass.where('age < :age', age: 40).where(first_name: 'Alex').all).to contain_exactly(obj3)
    end

    context 'Query' do
      it 'filters by specified conditions' do
        obj = klass.create!(first_name: 'Alex', age: 42)

        expect(klass.where(id: obj.id).where('age = :age', age: 42).all.to_a).to eq([obj])
        expect(klass.where(id: obj.id).where('age <> :age', age: 42).all.to_a).to eq([])
      end
    end

    context 'Scan' do
      it 'filters by specified conditions' do
        obj = klass.create!(first_name: 'Alex', age: 42)
        expect(klass.where('age = :age', age: 42).all.to_a).to eq([obj])
      end

      it 'performs Scan when key attributes are used only in String query' do
        obj = klass.create!(first_name: 'Alex', age: 42)

        expect(Dynamoid.adapter.client).to receive(:scan).and_call_original
        expect(klass.where('id = :id', id: obj.id).all.to_a).to eq([obj])
      end
    end
  end

  describe '#find_by_pages' do
    let(:model) do
      new_class do
        self.range_key = :range
        field :city
        field :age, :number
        field :range, :number
        field :data
      end
    end

    before do
      120.times do |i|
        model.create(
          id: '1',
          range: i.to_f,
          age: i.to_f,
          data: 'A' * 1024 * 16
        )
      end
    end

    it 'yields one page at a time' do
      expect { |b| model.where(id: '1').find_by_pages(&b) }.to yield_successive_args(
        [all(be_a(model)), { last_evaluated_key: an_instance_of(Hash) }],
        [all(be_a(model)), { last_evaluated_key: nil }],
      )
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          field :name
          after_initialize { print 'run after_initialize' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect do
          klass_with_callback.where(name: 'Alex').find_by_pages { |*| } # rubocop:disable Lint/EmptyBlock
        end.to output('run after_initialize').to_stdout
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          field :name
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect do
          klass_with_callback.where(name: 'Alex').find_by_pages { |*| } # rubocop:disable Lint/EmptyBlock
        end.to output('run after_find').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          field :name
          after_initialize { print 'run after_initialize' }
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!(name: 'Alex')

        expect do
          klass_with_callback.where(name: 'Alex').find_by_pages { |*| } # rubocop:disable Lint/EmptyBlock
        end.to output('run after_initializerun after_find').to_stdout
      end
    end
  end

  describe '#start' do
    let(:model) do
      new_class(partition_key: :name) do
        field :city
      end
    end

    it 'returns result from the specified item' do
      customer1 = model.create(name: 'Bob', city: 'San Francisco')
      customer2 = model.create(name: 'Jeff', city: 'San Francisco')
      customer3 = model.create(name: 'Mark', city: 'San Francisco')
      customer4 = model.create(name: 'Greg', city: 'New York')

      chain = described_class.new(model)

      customers = chain.where(city: 'San Francisco').record_limit(2).to_a
      expect(customers.size).to eq 2

      customers_rest = chain.where(city: 'San Francisco').start(customers.last).all.to_a
      expect(customers_rest.size).to eq 1

      expect(customers + customers_rest).to contain_exactly(customer1, customer2, customer3)
    end

    it 'accepts hash argument' do
      customer1 = model.create(name: 'Bob', city: 'San Francisco')
      customer2 = model.create(name: 'Jeff', city: 'San Francisco')
      customer3 = model.create(name: 'Mark', city: 'San Francisco')
      customer4 = model.create(name: 'Greg', city: 'New York')

      chain = described_class.new(model)

      customers = chain.where(city: 'San Francisco').record_limit(2).to_a
      expect(customers.size).to eq 2

      customers_rest = chain.where(city: 'San Francisco').start(name: customers.last.name).all.to_a
      expect(customers_rest.size).to eq 1

      expect(customers + customers_rest).to contain_exactly(customer1, customer2, customer3)
    end

    context 'document with range key' do
      let(:model) do
        Class.new do
          include Dynamoid::Document
          table name: :customer, key: :version
          range :age, :integer
          field :name
          field :gender
        end
      end

      before do
        @customer1 = model.create(version: 'v1', name: 'Bob', age: 10, gender: 'male')
        @customer2 = model.create(version: 'v1', name: 'Jeff', age: 15, gender: 'female')
        @customer3 = model.create(version: 'v1', name: 'Mark', age: 20, gender: 'male')
        @customer4 = model.create(version: 'v1', name: 'Greg', age: 25, gender: 'female')
      end

      it 'return query result from the specified item' do
        chain = described_class.new(model)

        expect(chain).to receive(:raw_pages_via_query).and_call_original
        customers = chain.where(version: 'v1', 'age.gt': 10).start(@customer2).all.to_a

        expect(customers).to contain_exactly(@customer3, @customer4)
      end

      it 'return scan result from the specified item' do
        chain = described_class.new(model)

        expect(chain).to receive(:raw_pages_via_scan).and_call_original
        customers = chain.where(gender: 'male').start(@customer1).all.to_a

        expect(customers).to contain_exactly(@customer3)
      end
    end

    context 'document without range key' do
      let(:model) do
        new_class(partition_key: :name) do
          field :age, :integer
        end
      end

      before do
        @customer1 = model.create(name: 'Bob', age: 10)
        @customer2 = model.create(name: 'Jeff', age: 15)
        @customer3 = model.create(name: 'Mark', age: 20)
        @customer4 = model.create(name: 'Greg', age: 25)
      end

      it 'return scan result from the specified item' do
        chain = described_class.new(model)

        expect(chain).to receive(:raw_pages_via_scan).and_call_original
        customers = chain.where('age.gt': 10).start(@customer2).all.to_a

        expect(customers).to contain_exactly(@customer3, @customer4)
      end
    end
  end

  describe '#delete_all' do
    it 'deletes in batch' do
      klass = new_class
      klass.create!

      chain = described_class.new(klass)

      expect(Dynamoid.adapter.client).to receive(:batch_write_item).and_call_original
      chain.delete_all
    end

    context 'when some conditions specified' do
      it 'deletes only proper items' do
        klass = new_class do
          field :title
        end

        document1 = klass.create!(title: 'Doc #1')
        klass.create!(title: 'Doc #2')
        document3 = klass.create!(title: 'Doc #3')

        chain = described_class.new(klass)
        chain = chain.where(title: 'Doc #2')

        expect { chain.delete_all }.to change { klass.count }.by(-1)
        expect(klass.all).to contain_exactly(document1, document3)
      end

      it 'loads items with Query if can' do
        klass = new_class do
          range :title
        end

        document = klass.create!(title: 'Doc #1')

        chain = described_class.new(klass)
        chain = chain.where(id: document.id)

        expect(Dynamoid.adapter.client).to receive(:query).and_call_original
        expect { chain.delete_all }.to change { klass.count }.by(-1)
      end

      it 'loads items with Scan if cannot use Query' do
        klass = new_class do
          range :title
          field :author
        end

        klass.create!(title: "The Cuckoo's Calling", author: 'J. K. Rowling')

        chain = described_class.new(klass)
        chain = chain.where(author: 'J. K. Rowling')

        expect(Dynamoid.adapter.client).to receive(:scan).and_call_original
        expect { chain.delete_all }.to change { klass.count }.by(-1)
      end

      context 'Query (partition key specified)' do
        it 'works well with composite primary key' do
          klass = new_class do
            range :title
          end

          document = klass.create!(title: 'Doc #1')
          klass.create!(title: 'Doc #2')

          chain = described_class.new(klass)
          chain = chain.where(id: document.id)

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end

        it 'works well when there is partition key only' do
          klass = new_class do
            field :title
          end

          document = klass.create!
          klass.create!

          chain = described_class.new(klass)
          chain = chain.where(id: document.id)

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end

        it 'works well when #where is called with a String query' do
          klass = new_class do
            field :title
          end

          document = klass.create!(title: 'title#1')
          klass.create!

          chain = described_class.new(klass)
          chain = chain.where(id: document.id).where('title = :v', v: document.title)

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end
      end

      context 'Scan (partition key is not specified)' do
        it 'works well with composite primary key' do
          klass = new_class do
            range :title
          end

          klass.create!(title: 'Doc #1')
          klass.create!(title: 'Doc #2')

          chain = described_class.new(klass)
          chain = chain.where(title: 'Doc #1')

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end

        it 'works well when there is partition key only' do
          klass = new_class do
            field :title
          end

          klass.create!(title: 'Doc #1')
          klass.create!(title: 'Doc #2')

          chain = described_class.new(klass)
          chain = chain.where(title: 'Doc #1')

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end

        it 'works well when #where is called with a String query' do
          klass = new_class do
            field :title
          end

          klass.create!(title: 'Doc #1')
          klass.create!(title: 'Doc #2')

          chain = described_class.new(klass)
          chain = chain.where('title = :v', v: 'Doc #1')

          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end
      end
    end

    context 'there are no conditions' do
      it 'deletes all the items' do
        klass = new_class do
          field :title
        end

        3.times { klass.create! }
        chain = described_class.new(klass)
        expect { chain.delete_all }.to change { klass.count }.from(3).to(0)
      end

      context 'Scan' do
        it 'works well with composite primary key' do
          klass = new_class do
            range :title
          end

          klass.create!(title: 'Doc #1')
          chain = described_class.new(klass)
          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end

        it 'works well when there is partition key only' do
          klass = new_class

          klass.create!
          chain = described_class.new(klass)
          expect { chain.delete_all }.to change { klass.count }.by(-1)
        end
      end
    end
  end

  describe '#first' do
    let(:model) do
      new_class partition_key: :name do
        range :age, :integer
        field :city, :string
      end
    end

    it 'applies a scan limit if no conditions are present' do
      document = model.create(name: 'Bob', age: 5)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).to receive(:scan_limit).with(1).and_call_original
      expect(chain.first).to eq(document)
    end

    it 'applies the correct scan limit if no conditions are present' do
      document1 = model.create(name: 'Bob', age: 5)
      document2 = model.create(name: 'Bob', age: 6)
      document3 = model.create(name: 'Bob', age: 7)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).to receive(:scan_limit).with(2).and_call_original
      expect(chain.first(2).to_set).to eq([document1, document2].to_set)
    end

    it 'applies a record limit if only key conditions are present' do
      document = model.create(name: 'Bob', age: 5)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).to receive(:record_limit).with(1).and_call_original
      expect(chain.where(name: 'Bob', age: 5).first).to eq(document)
    end

    it 'applies the correct record limit if only key conditions are present' do
      document1 = model.create(name: 'Bob', age: 5)
      document2 = model.create(name: 'Bob', age: 6)
      document3 = model.create(name: 'Bob', age: 7)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).to receive(:record_limit).with(2).and_call_original
      expect(chain.where(name: 'Bob').first(2)).to eq([document1, document2])
    end

    it 'does not apply a record limit if the hash key is missing' do
      document = model.create(name: 'Bob', city: 'New York', age: 5)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).not_to receive(:record_limit)
      expect(chain.where(age: 5).first).to eq(document)
    end

    it 'does not apply a record limit if non-key conditions are present' do
      document = model.create(name: 'Bob', city: 'New York', age: 5)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).not_to receive(:record_limit)
      expect(chain.where(city: 'New York').first).to eq(document)
      expect(chain.where(name: 'Bob', city: 'New York').first).to eq(document)
      expect(chain.where(name: 'Bob', age: 5, city: 'New York').first).to eq(document)
    end

    it 'does not apply a record limit if non-equality conditions are present' do
      document1 = model.create(name: 'Bob', age: 5)
      document2 = model.create(name: 'Alice', age: 6)

      chain = described_class.new(model)
      expect_any_instance_of(described_class).not_to receive(:record_limit)
      expect(chain.where('name.gt': 'Alice').first).to eq(document1)
    end

    it 'returns nil if no matching document is present' do
      model.create(name: 'Bob', age: 5)

      expect(model.where(name: 'Alice').first).to be_nil
    end

    it 'returns the first document with regards to the sort order' do
      document1 = model.create(name: 'Bob', age: 5)
      document2 = model.create(name: 'Bob', age: 9)
      document3 = model.create(name: 'Bob', age: 12)

      expect(model.first.age).to eq(5)
    end

    it 'returns the first document matching the criteria and with regards to the sort order' do
      document1 = model.create(name: 'Bob', age: 4)
      document3 = model.create(name: 'Alice', age: 6)
      document4 = model.create(name: 'Alice', age: 8)

      expect(model.where(name: 'Alice').first.age).to eq(6)
    end

    context 'scope is reused' do
      it 'does not affect other query methods when no key conditions' do
        klass = new_class do
          field :name
        end

        klass.create!(name: 'Alice')
        klass.create!(name: 'Lucy')

        scope = klass.where({})
        expect(scope.first).to be_present
        expect(scope.count).to eq 2
        expect(scope.to_a.size).to eq 2
      end

      it 'does not affect other query methods when passed key conditions' do
        klass = new_class do
          range :name
        end

        klass.create!(id: '1', name: 'Alice')
        klass.create!(id: '1', name: 'Anne')
        klass.create!(id: '1', name: 'Lucy')

        scope = klass.where(id: '1')
        expect(scope.first).to be_present
        expect(scope.count).to eq 3
        expect(scope.all.to_a.size).to eq 3
      end
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
        end

        object = klass_with_callback.create!

        expect do
          klass_with_callback.first
        end.to output('run after_initialize').to_stdout
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect do
          klass_with_callback.first
        end.to output('run after_find').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect do
          klass_with_callback.first
        end.to output('run after_initializerun after_find').to_stdout
      end
    end
  end

  describe '#count' do
    describe 'Query vs Scan' do
      it 'Scans when query is empty' do
        chain = described_class.new(Address)
        chain = chain.where({})
        expect(chain).to receive(:count_via_scan)
        chain.count
      end

      it 'Queries when query is only ID' do
        chain = described_class.new(Address)
        chain = chain.where(id: 'test')
        expect(chain).to receive(:count_via_query)
        chain.count
      end

      it 'Queries when query contains ID' do
        chain = described_class.new(Address)
        chain = chain.where(id: 'test', city: 'Bucharest')
        expect(chain).to receive(:count_via_query)
        chain.count
      end

      it 'Scans when query includes keys that are neither a hash nor a range' do
        chain = described_class.new(Address)
        chain = chain.where(city: 'Bucharest')
        expect(chain).to receive(:count_via_scan)
        chain.count
      end

      it 'Scans when query is only a range' do
        chain = described_class.new(Tweet)
        chain = chain.where(group: 'xx')
        expect(chain).to receive(:count_via_scan)
        chain.count
      end

      it 'Scans when there is only not-equal operator for hash key' do
        chain = described_class.new(Address)
        chain = chain.where('id.in': ['test'])
        expect(chain).to receive(:count_via_scan)
        chain.count
      end
    end

    context 'Query' do
      let(:model) do
        Class.new do
          include Dynamoid::Document

          table name: :customer, key: :name
          range :age, :integer
          field :year_of_birth, :integer
        end
      end

      it 'returns count of filtered documents' do
        customer1 = model.create(name: 'Bob', age: 5)
        customer2 = model.create(name: 'Bob', age: 9)
        customer3 = model.create(name: 'Bob', age: 12)

        expect(model.where(name: 'Bob', 'age.lt': 10).count).to eql(2)
      end

      it 'returns count of filtered documents when #where called with a String query' do
        customer1 = model.create(name: 'Bob', age: 5, year_of_birth: 2000)
        customer2 = model.create(name: 'Bob', age: 9, year_of_birth: 2010)
        customer3 = model.create(name: 'Bob', age: 12, year_of_birth: 2020)

        expect(
          model.where(name: 'Bob', 'age.lt': 10)
          .where('year_of_birth > :year', year: 2005)
          .count
        ).to eql(1)
      end
    end

    context 'Scan' do
      let(:model) do
        new_class do
          field :age, :integer
        end
      end

      it 'returns count of filtered documents' do
        customer1 = model.create(age: 5)
        customer2 = model.create(age: 9)
        customer3 = model.create(age: 12)

        expect(model.where('age.lt': 10).count).to eql(2)
      end

      it 'returns count of filtered documents when #where called with a String query' do
        customer1 = model.create(age: 5)
        customer2 = model.create(age: 9)
        customer3 = model.create(age: 12)

        expect(model.where('age < :age', age: 10).count).to eql(2)
      end
    end
  end

  describe '#project' do
    let(:model) do
      new_class do
        field :name
        field :age, :integer
      end
    end

    it 'loads only specified attributes' do
      model.create(name: 'Alex', age: 21)
      obj, = model.project(:age).to_a

      expect(obj.age).to eq 21

      expect(obj.id).to eq nil
      expect(obj.name).to eq nil
    end

    it 'works with Scan' do
      model.create(name: 'Alex', age: 21)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_scan).and_call_original

      obj, = chain.project(:age).to_a
      expect(obj.attributes).to eq(age: 21)
    end

    it 'works with Query' do
      obj = model.create(name: 'Alex', age: 21)

      chain = described_class.new(model)
      expect(chain).to receive(:raw_pages_via_query).and_call_original

      obj_loaded, = chain.where(id: obj.id).project(:age).to_a
      expect(obj_loaded.attributes).to eq(age: 21)
    end

    context 'when attribute name is a DynamoDB reserved word' do
      let(:model) do
        new_class do
          field :name
          field :bucket, :integer # BUCKET is a reserved word
        end
      end

      it 'works with Scan' do
        model.create(name: 'Alex', bucket: 2)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_scan).and_call_original

        obj, = chain.project(:bucket).to_a
        expect(obj.attributes).to eq(bucket: 2)
      end

      it 'works with Query' do
        object = model.create(name: 'Alex', bucket: 2)

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original

        obj, = chain.where(id: object.id).project(:bucket).to_a
        expect(obj.attributes).to eq(bucket: 2)
      end
    end

    context 'when attribute name contains special characters' do
      let(:model) do
        new_class do
          field :'first:name'
        end
      end

      it 'works with Scan' do
        model.create('first:name': 'Alex')

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_scan).and_call_original

        obj, = chain.project(:'first:name').to_a
        expect(obj.attributes).to eq('first:name': 'Alex')
      end

      it 'works with Query' do
        object = model.create('first:name': 'Alex')

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original

        obj, = chain.where(id: object.id).project(:'first:name').to_a
        expect(obj.attributes).to eq('first:name': 'Alex')
      end
    end

    context 'when attribute name starts with _' do
      let(:model) do
        new_class do
          field :_name
        end
      end

      it 'works with Scan' do
        model.create(_name: 'Alex')

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_scan).and_call_original

        obj, = chain.project(:_name).to_a
        expect(obj.attributes).to eq(_name: 'Alex')
      end

      it 'works with Query' do
        object = model.create(_name: 'Alex')

        chain = described_class.new(model)
        expect(chain).to receive(:raw_pages_via_query).and_call_original

        obj, = chain.where(id: object.id).project(:_name).to_a
        expect(obj.attributes).to eq(_name: 'Alex')
      end
    end
  end

  describe '#pluck' do
    let(:model) do
      new_class do
        field :name, :string
        field :age, :integer
      end
    end

    it 'returns an array of attribute values' do
      model.create(name: 'Alice', age: 21)
      model.create(name: 'Bob', age: 34)

      expect(model.pluck(:name)).to contain_exactly('Alice', 'Bob')
    end

    it 'returns an array of arrays of attribute values if requested several attributes' do
      model.create(name: 'Alice', age: 21)
      model.create(name: 'Bob', age: 34)

      expect(model.pluck(:name, :age)).to contain_exactly(['Alice', 21], ['Bob', 34])
    end

    it 'can be chained with where clause' do
      model.create(name: 'Alice', age: 21)
      model.create(name: 'Bob', age: 34)

      expect(model.where('age.gt': 30).pluck(:name)).to eq(['Bob'])
    end

    it 'accepts both string and symbolic attribute names' do
      model.create(name: 'Alice', age: 21)

      expect(model.pluck(:name)).to eq(['Alice'])
      expect(model.pluck('name')).to eq(['Alice'])
      expect(model.pluck('name', :age)).to eq([['Alice', 21]])
    end

    it 'casts values to declared field types' do
      model.create(created_at: '03-04-2020 23:40:00'.to_time)

      expect(model.pluck(:created_at)).to eq(['03-04-2020 23:40:00'.to_time])
    end

    context 'scope is reused' do
      it 'does not affect other query methods when there is one field to fetch' do
        klass = new_class do
          field :name
          field :age, :integer
        end

        klass.create!(name: 'Alice', age: 11)
        scope = klass.where({})

        scope.pluck(:name)
        array = scope.all.to_a

        object = array[0]
        expect(object.name).to eq 'Alice'
        expect(object.age).to eq 11
      end

      it 'does not affect other query methods when there are several fields to fetch' do
        klass = new_class do
          field :name
          field :age, :integer
          field :tag_id
        end

        klass.create!(name: 'Alice', age: 11, tag_id: '719')
        scope = klass.where({})

        scope.pluck(:name, :age)
        array = scope.all.to_a

        object = array[0]
        expect(object.name).to eq 'Alice'
        expect(object.age).to eq 11
        expect(object.tag_id).to eq '719'
      end
    end

    context 'when attribute name is a DynamoDB reserved word' do
      let(:model) do
        new_class do
          field :name
          field :bucket, :integer # BUCKET is a reserved word
        end
      end

      it 'works with Scan' do
        model.create(name: 'Alice', bucket: 1001)
        model.create(name: 'Bob', bucket: 1002)

        expect(model.pluck(:bucket)).to contain_exactly(1001, 1002)
      end

      it 'works with Query' do
        object = model.create(name: 'Alice', bucket: 1001)

        expect(model.where(id: object.id).pluck(:bucket)).to eq([1001])
      end
    end

    context 'when attribute name contains special characters' do
      let(:model) do
        new_class do
          field :'first:name'
        end
      end

      it 'works with Scan' do
        model.create('first:name': 'Alice')
        model.create('first:name': 'Bob')

        expect(model.pluck(:'first:name')).to contain_exactly('Alice', 'Bob')
      end

      it 'works with Query' do
        object = model.create('first:name': 'Alice')

        expect(model.where(id: object.id).pluck(:'first:name')).to eq(['Alice'])
      end
    end

    context 'when attribute name starts with _' do
      let(:model) do
        new_class do
          field :_name
        end
      end

      it 'works with Scan' do
        model.create(_name: 'Alice')
        model.create(_name: 'Bob')

        expect(model.pluck(:_name)).to contain_exactly('Alice', 'Bob')
      end

      it 'works with Query' do
        object = model.create(_name: 'Alice')

        expect(model.where(id: object.id).pluck(:_name)).to eq(['Alice'])
      end
    end
  end

  describe 'User' do
    let(:chain) { described_class.new(User) }

    it 'defines each' do
      chain = self.chain.where(name: 'Josh')
      chain.each { |u| u.update_attribute(:name, 'Justin') }

      expect(User.find(user.id).name).to eq 'Justin'
    end

    it 'includes Enumerable' do
      chain = self.chain.where(name: 'Josh')

      expect(chain.collect(&:name)).to eq ['Josh']
    end
  end

  describe 'Tweet' do
    let!(:tweet1) { Tweet.create(tweet_id: 'x', group: 'one') }
    let!(:tweet2) { Tweet.create(tweet_id: 'x', group: 'two') }
    let!(:tweet3) { Tweet.create(tweet_id: 'xx', group: 'two') }
    let(:tweets) { [tweet1, tweet2, tweet3] }
    let(:chain) { described_class.new(Tweet) }

    it 'limits evaluated records' do
      chain = self.chain.where({})
      expect(chain.record_limit(1).count).to eq 1
      expect(chain.record_limit(2).count).to eq 2
    end

    it 'finds tweets with a start' do
      chain = self.chain.where(tweet_id: 'x')
      chain.start(tweet1)
      expect(chain.count).to eq 1
      expect(chain.first).to eq tweet2
    end

    it 'finds one specific tweet' do
      chain = self.chain.where(tweet_id: 'xx', group: 'two')
      expect(chain.all.to_a).to eq [tweet3]
    end

    it 'finds posts with "where" method with "gt" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(post_id: 'x', posted_at: time)
      post2 = Post.create(post_id: 'x', posted_at: (time + 1.hour))
      chain = described_class.new(Post)
      chain = chain.where(post_id: 'x', 'posted_at.gt': (time + ts_epsilon))
      expect(chain.count).to eq 1
      stored_record = chain.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post2.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post2.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post2.attributes[:updated_at])
    end

    it 'finds posts with "where" method with "lt" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(post_id: 'x', posted_at: time)
      post2 = Post.create(post_id: 'x', posted_at: (time + 1.hour))
      chain = described_class.new(Post)
      chain = chain.where(post_id: 'x', 'posted_at.lt': (time + 1.hour - ts_epsilon))
      expect(chain.count).to eq 1
      stored_record = chain.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post1.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post1.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post1.attributes[:updated_at])
    end

    it 'finds posts with "where" method with "between" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(post_id: 'x', posted_at: time)
      post2 = Post.create(post_id: 'x', posted_at: (time + 1.hour))
      chain = described_class.new(Post)
      chain = chain.where(post_id: 'x', 'posted_at.between': [time - ts_epsilon, time + ts_epsilon])
      expect(chain.count).to eq 1
      stored_record = chain.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post1.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post1.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post1.attributes[:updated_at])
    end

    describe 'batch queries' do
      it 'returns all results' do
        expect(chain.batch(2).all.count).to eq tweets.size
      end
    end
  end

  describe '#with_index' do
    context 'when Local Secondary Index (LSI) used' do
      let(:klass_with_local_secondary_index) do
        new_class do
          range :owner_id

          field :age, :integer

          local_secondary_index range_key: :age,
                                name: :age_index, projected_attributes: :all
        end
      end

      before do
        klass_with_local_secondary_index.create(id: 'the same id', owner_id: 'a', age: 3)
        klass_with_local_secondary_index.create(id: 'the same id', owner_id: 'c', age: 2)
        klass_with_local_secondary_index.create(id: 'the same id', owner_id: 'b', age: 1)
      end

      it 'sorts the results in ascending order' do
        chain = described_class.new(klass_with_local_secondary_index)
        models = chain.where(id: 'the same id').with_index(:age_index).scan_index_forward(true)
        expect(models.map(&:owner_id)).to eq %w[b c a]
      end

      it 'sorts the results in desc order' do
        chain = described_class.new(klass_with_local_secondary_index)
        models = chain.where(id: 'the same id').with_index(:age_index).scan_index_forward(false)
        expect(models.map(&:owner_id)).to eq %w[a c b]
      end
    end

    context 'when Global Secondary Index (GSI) used' do
      let(:klass_with_global_secondary_index) do
        new_class do
          range :owner_id

          field :age, :integer

          global_secondary_index hash_key: :owner_id, range_key: :age,
                                 name: :age_index, projected_attributes: :all
        end
      end
      let(:chain) { described_class.new(klass_with_global_secondary_index) }

      before do
        klass_with_global_secondary_index.create(id: 'other id',    owner_id: 'a', age: 1)
        klass_with_global_secondary_index.create(id: 'the same id', owner_id: 'a', age: 3)
        klass_with_global_secondary_index.create(id: 'the same id', owner_id: 'c', age: 2)
        klass_with_global_secondary_index.create(id: 'no age', owner_id: 'b')
      end

      it 'sorts the results in ascending order' do
        models = chain.where(owner_id: 'a').with_index(:age_index).scan_index_forward(true)
        expect(models.map(&:age)).to eq [1, 3]
      end

      it 'sorts the results in desc order' do
        models = chain.where(owner_id: 'a').with_index(:age_index).scan_index_forward(false)
        expect(models.map(&:age)).to eq [3, 1]
      end

      it 'works with string names' do
        models = chain.where(owner_id: 'a').with_index('age_index').scan_index_forward(false)
        expect(models.map(&:age)).to eq [3, 1]
      end

      it 'raises an error when an unknown index is passed' do
        expect do
          chain.where(owner_id: 'a').with_index(:missing_index)
        end.to raise_error Dynamoid::Errors::InvalidIndex, /Unknown index/
      end

      it 'allows scanning the index' do
        models = chain.with_index(:age_index)
        expect(models.map(&:id)).not_to include 'no age'
      end
    end
  end

  describe '#scan_index_forward' do
    let(:klass_with_range_key) do
      new_class do
        range :name
        field :age, :integer
      end
    end

    it 'returns collection sorted in ascending order by range key when called with true' do
      klass_with_range_key.create(id: 'the same id', name: 'a')
      klass_with_range_key.create(id: 'the same id', name: 'c')
      klass_with_range_key.create(id: 'the same id', name: 'b')

      chain = described_class.new(klass_with_range_key)
      models = chain.where(id: 'the same id').scan_index_forward(true)
      expect(models.map(&:name)).to eq %w[a b c]
    end

    it 'returns collection sorted in descending order by range key when called with false' do
      klass_with_range_key.create(id: 'the same id', name: 'a')
      klass_with_range_key.create(id: 'the same id', name: 'c')
      klass_with_range_key.create(id: 'the same id', name: 'b')

      chain = described_class.new(klass_with_range_key)
      models = chain.where(id: 'the same id').scan_index_forward(false)
      expect(models.map(&:name)).to eq %w[c b a]
    end

    it 'overides previous calls' do
      klass_with_range_key.create(id: 'the same id', name: 'a')
      klass_with_range_key.create(id: 'the same id', name: 'c')
      klass_with_range_key.create(id: 'the same id', name: 'b')

      chain = described_class.new(klass_with_range_key)
      models = chain.where(id: 'the same id').scan_index_forward(false).scan_index_forward(true)
      expect(models.map(&:name)).to eq %w[a b c]
    end

    context 'when Scan conditions' do
      it 'does not affect query without conditions on hash' do
        klass_with_range_key.create(id: 'the same id', name: 'a')
        klass_with_range_key.create(id: 'the same id', name: 'c')
        klass_with_range_key.create(id: 'the same id', name: 'b')

        chain = described_class.new(klass_with_range_key)
        models = chain.where('name.gte': 'a').scan_index_forward(false)
        expect(models.map(&:name)).not_to eq %w[c b a]
      end
    end

    context 'when Local Secondary Index (LSI) used' do
      let(:klass_with_local_secondary_index) do
        new_class do
          range :name
          field :age, :integer

          local_secondary_index range_key: :age, name: :age_index, projected_attributes: :all
        end
      end

      it 'affects a query' do
        klass_with_local_secondary_index.create(id: 'the same id', age: 30, name: 'a')
        klass_with_local_secondary_index.create(id: 'the same id', age: 10, name: 'c')
        klass_with_local_secondary_index.create(id: 'the same id', age: 20, name: 'b')

        chain = described_class.new(klass_with_local_secondary_index)
        models = chain.where(id: 'the same id', 'age.gt': 0).scan_index_forward(false)
        expect(models.map(&:age)).to eq [30, 20, 10]
        expect(chain.key_fields_detector.index_name).to eq(:age_index)
      end
    end

    context 'when Global Secondary Index (GSI) used' do
      let(:klass_with_global_secondary_index) do
        new_class do
          range :name
          field :age, :integer
          field :nickname

          global_secondary_index hash_key: :age, range_key: :nickname, name: :age_nickname_index, projected_attributes: :all
        end
      end

      it 'affects a query' do
        klass_with_global_secondary_index.create(age: 30, nickname: 'a', name: 'b')
        klass_with_global_secondary_index.create(age: 30, nickname: 'c', name: 'c')
        klass_with_global_secondary_index.create(age: 30, nickname: 'b', name: 'a')

        chain = described_class.new(klass_with_global_secondary_index)
        models = chain.where(age: 30).scan_index_forward(false)
        expect(models.map(&:nickname)).to eq %w[c b a]
        expect(chain.key_fields_detector.index_name).to eq(:age_nickname_index)
      end
    end
  end
end
