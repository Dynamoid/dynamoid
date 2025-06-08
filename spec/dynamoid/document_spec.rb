# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Document do
  it 'runs load hooks' do
    result = nil
    ActiveSupport.on_load(:dynamoid) { |loaded| result = loaded }

    expect(result).to eq(described_class)
  end

  it 'initializes a new document' do
    address = Address.new

    expect(address.new_record).to be_truthy
    expect(address.attributes).to eq({})
  end

  it 'responds to will_change! methods for all fields' do
    address = Address.new
    expect(address).to respond_to(:id_will_change!)
    expect(address).to respond_to(:options_will_change!)
    expect(address).to respond_to(:created_at_will_change!)
    expect(address).to respond_to(:updated_at_will_change!)
  end

  it 'initializes a new document with attributes' do
    address = Address.new(city: 'Chicago')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq(city: 'Chicago')
  end

  it 'initializes a new document with a virtual attribute' do
    address = Address.new(zip_code: '12345')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq(city: 'Chicago')
  end

  it 'ignores unknown fields (does not raise error)' do
    klass = new_class do
      field :city
    end

    model = klass.new(unknown_field: 'test', city: 'Chicago')
    expect(model.city).to eql 'Chicago'
  end

  describe '#initialize' do
    let(:klass) do
      new_class do
        field :foo
      end
    end

    context 'when block specified' do
      it 'calls a block and passes a model as argument' do
        object = klass.new(foo: 'bar') do |obj|
          obj.foo = 'baz'
        end

        expect(object.foo).to eq('baz')
      end
    end

    describe 'type casting' do
      let(:klass) do
        new_class do
          field :count, :integer
        end
      end

      it 'type casts attributes' do
        obj = klass.new(count: '101')
        expect(obj.attributes[:count]).to eql(101)
      end
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
        end

        expect { klass_with_callback.new }.to output('run after_initialize').to_stdout
      end
    end
  end

  describe '.exist?' do
    it 'checks if there is a document with specified primary key' do
      address = Address.create(city: 'Chicago')

      expect(Address).to exist(address.id)
      expect(Address).not_to exist('does-not-exist')
    end

    it 'supports an array of primary keys' do
      address_1 = Address.create(city: 'Chicago')
      address_2 = Address.create(city: 'New York')
      address_3 = Address.create(city: 'Los Angeles')

      expect(Address).to exist([address_1.id, address_2.id])
      expect(Address).not_to exist([address_1.id, 'does-not-exist'])
    end

    it 'supports hash with conditions' do
      address = Address.create(city: 'Chicago')

      expect(Address).to exist(city: address.city)
      expect(Address).not_to exist(city: 'does-not-exist')
    end

    it 'checks if there any document in table at all if called without argument' do
      Address.create_table(sync: true)
      expect(Address.count).to eq 0

      expect { Address.create }.to change(Address, :exists?).from(false).to(true)
    end
  end

  it 'gets errors courtesy of ActiveModel' do
    address = Address.create(city: 'Chicago')

    expect(address.errors).to be_empty
    expect(address.errors.full_messages).to be_empty
  end

  describe '#hash_key' do
    context 'when there is already an attribute with name `hash_key`' do
      let(:klass) do
        new_class do
          field :hash_key
        end
      end

      it 'returns id value if hash_key attribute is not set' do
        obj = klass.new(id: 'id')

        expect(obj.id).to eq 'id'
        expect(obj.hash_key).to eq 'id'
      end

      it 'returns hash_key value if hash_key attribute is set' do
        obj = klass.new(id: 'id', hash_key: 'hash key')

        expect(obj.id).to eq 'hash key'
        expect(obj.hash_key).to eq 'hash key'
      end
    end

    context 'when hash key attribute name is `hash_key`' do
      let(:klass) do
        new_class do
          table key: :hash_key
        end
      end

      it 'returns id value' do
        obj = klass.new(hash_key: 'hash key')
        expect(obj.hash_key).to eq 'hash key'
      end
    end
  end

  describe '#range_value' do
    context 'when there is already an attribute with name `range_key`' do
      let(:klass) do
        new_class do
          range :name
          field :range_value
        end
      end

      it 'returns range key value if range_key attribute is not set' do
        obj = klass.new(name: 'name')

        expect(obj.name).to eq 'name'
        expect(obj.range_value).to eq 'name'
      end

      it 'returns range_key value if range_key attribute is set' do
        obj = klass.new(name: 'name', range_value: 'range key')

        expect(obj.name).to eq 'range key'
        expect(obj.range_value).to eq 'range key'
      end
    end

    context 'when range key attribute name is `range_value`' do
      let(:klass) do
        new_class do
          range :range_value
        end
      end

      it 'returns range key value' do
        obj = klass.new(range_value: 'range key')
        expect(obj.range_value).to eq 'range key'
      end
    end
  end

  shared_examples 'it has equality testing and hashing' do
    it 'is equal to itself' do
      expect(document).to eq document # rubocop:disable RSpec/IdenticalEqualityAssertion
    end

    it 'is equal to another document with the same key(s)' do
      expect(document).to eq same
    end

    it 'is not equal to another document with different key(s)' do
      expect(document).not_to eq different
    end

    it 'is not equal to an object that is not a document' do
      expect(document).not_to eq 'test'
    end

    it 'is not equal to nil' do
      expect(document).not_to eq nil
    end

    it 'hashes documents with the keys to the same value' do
      expect(document => 1).to have_key(same)
    end
  end

  context 'without a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document) { Address.create(id: 123, city: 'Seattle') }
      let(:different) { Address.create(id: 456, city: 'Seattle') }
      let(:same) { Address.new(id: 123, city: 'Boston') }
    end
  end

  context 'with a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document) { Tweet.create(tweet_id: 'x', group: 'abc', msg: 'foo') }
      let(:different) { Tweet.create(tweet_id: 'y', group: 'abc', msg: 'foo') }
      let(:same) { Tweet.new(tweet_id: 'x', group: 'abc', msg: 'bar') }
    end

    it 'is not equal to another document with the same hash key but a different range value' do
      document = Tweet.create(tweet_id: 'x', group: 'abc')
      different = Tweet.create(tweet_id: 'x', group: 'xyz')

      expect(document).not_to eq different
    end
  end

  describe '#count' do
    it 'returns the number of documents in the table' do
      document = Tweet.create(tweet_id: 'x', group: 'abc')
      different = Tweet.create(tweet_id: 'x', group: 'xyz')

      expect(Tweet.count).to eq 2
    end
  end

  describe '.deep_subclasses' do
    it 'returns direct children' do
      expect(Car.deep_subclasses).to eq [Cadillac]
    end

    it 'returns grandchildren too' do
      expect(Vehicle.deep_subclasses).to include(Cadillac)
    end
  end

  describe '#inspect' do
    it 'returns a String containing a model class name and a list of attributes and values' do
      klass = new_class(class_name: 'Person') do
        field :name
        field :age, :integer
      end

      object = klass.new(name: 'Alex', age: 21)
      expect(object.inspect).to eql '#<Person id: nil, name: "Alex", age: 21, created_at: nil, updated_at: nil>'
    end

    it 'puts partition and sort keys on the first place' do
      klass = new_class(class_name: 'Person') do
        field :name
        field :age, :integer
        range :city
      end

      object = klass.new(city: 'Kyiv')
      expect(object.inspect).to eql '#<Person id: nil, city: "Kyiv", name: nil, age: nil, created_at: nil, updated_at: nil>'
    end
  end
end
