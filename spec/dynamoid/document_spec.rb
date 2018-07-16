# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Document do
  it 'initializes a new document' do
    address = Address.new

    expect(address.new_record).to be_truthy
    expect(address.attributes).to eq(id: nil,
                                     created_at: nil,
                                     updated_at: nil,
                                     city: nil,
                                     options: nil,
                                     deliverable: nil,
                                     latitude: nil,
                                     config: nil,
                                     registered_on: nil,
                                     lock_version: nil)
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

    expect(address.attributes).to eq(id: nil,
                                     created_at: nil,
                                     updated_at: nil,
                                     city: 'Chicago',
                                     options: nil,
                                     deliverable: nil,
                                     latitude: nil,
                                     config: nil,
                                     registered_on: nil,
                                     lock_version: nil)
  end

  it 'initializes a new document with a virtual attribute' do
    address = Address.new(zip_code: '12345')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq(id: nil,
                                     created_at: nil,
                                     updated_at: nil,
                                     city: 'Chicago',
                                     options: nil,
                                     deliverable: nil,
                                     latitude: nil,
                                     config: nil,
                                     registered_on: nil,
                                     lock_version: nil)
  end

  it 'allows interception of write_attribute on load' do
    klass = Class.new do
      include Dynamoid::Document
      field :city
      def city=(value)
        self[:city] = value.downcase
      end
    end
    expect(klass.new(city: 'Chicago').city).to eq 'chicago'
  end

  it 'ignores unknown fields (does not raise error)' do
    klass = Class.new do
      include Dynamoid::Document
      field :city
    end

    model = klass.new(unknown_field: 'test', city: 'Chicago')
    expect(model.city).to eql 'Chicago'
  end

  it 'creates a new document' do
    address = Address.create(city: 'Chicago')

    expect(address.new_record).to be_falsey
    expect(address.id).to_not be_nil
  end

  it 'creates multiple documents' do
    addresses = Address.create([{ city: 'Chicago' }, { city: 'New York' }])

    expect(addresses.size).to eq 2
    expect(addresses.all?(&:persisted?)).to be true
    expect(addresses[0].city).to eq 'Chicago'
    expect(addresses[1].city).to eq 'New York'
  end

  it 'raises error when tries to save multiple invalid objects' do
    klass = Class.new do
      include Dynamoid::Document
      field :city
      validates :city, presence: true

      def self.name
        'Address'
      end
    end

    expect do
      klass.create!([{ city: 'Chicago' }, { city: nil }])
    end.to raise_error(Dynamoid::Errors::DocumentNotValid)
  end

  it 'knows if a document exists or not' do
    address = Address.create(city: 'Chicago')
    expect(Address.exists?(address.id)).to be_truthy
    expect(Address.exists?('does-not-exist')).to be_falsey
    expect(Address.exists?(city: address.city)).to be_truthy
    expect(Address.exists?(city: 'does-not-exist')).to be_falsey
  end

  it 'gets errors courtesy of ActiveModel' do
    address = Address.create(city: 'Chicago')

    expect(address.errors).to be_empty
    expect(address.errors.full_messages).to be_empty
  end

  describe '.update' do
    let(:document_class) do
      new_class do
        field :name

        validates :name, presence: true, length: { minimum: 5 }
        def self.name
          'Document'
        end
      end
    end

    it 'loads and saves document' do
      d = document_class.create(name: 'Document#1')

      expect do
        document_class.update(d.id, name: '[Updated]')
      end.to change { d.reload.name }.from('Document#1').to('[Updated]')
    end

    it 'returns updated document' do
      d = document_class.create(name: 'Document#1')
      d2 = document_class.update(d.id, name: '[Updated]')

      expect(d2).to be_a(document_class)
      expect(d2.name).to eq '[Updated]'
    end

    it 'does not save invalid document' do
      d = document_class.create(name: 'Document#1')
      d2 = nil

      expect do
        d2 = document_class.update(d.id, name: '[Up')
      end.not_to change { d.reload.name }
      expect(d2).not_to be_valid
    end

    it 'accepts range key value if document class declares it' do
      klass = new_class do
        field :name
        range :status
      end

      d = klass.create(status: 'old', name: 'Document#1')
      expect do
        klass.update(d.id, 'old', name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    it 'converts range key value to proper format' do
      klass = new_class do
        field :name
        range :activated_on, :date
        field :another_date, :datetime
      end

      d = klass.create(activated_on: '2018-01-14'.to_date, name: 'Document#1')
      expect do
        klass.update(d.id, '2018-01-14'.to_date, name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end
  end

  describe '.update_fields' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.update_fields(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.update_fields(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.update_fields(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    it 'checks the conditions on update' do
      obj = document_class.create(title: 'Old title', version: 1)
      expect do
        document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 1 })
      end.to change { document_class.find(obj.id).title }.to('New title')

      obj = document_class.create(title: 'Old title', version: 1)
      expect do
        result = document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
      end.not_to change { document_class.find(obj.id).title }
    end

    it 'does not create new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.update_fields('some-fake-id', title: 'Title')
      end.not_to change { document_class.count }
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.update_fields(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.update_fields(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.update_fields(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end
  end

  describe '.upsert' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.upsert(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.upsert(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.upsert(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    it 'checks the conditions on update' do
      obj = document_class.create(title: 'Old title', version: 1)
      expect do
        document_class.upsert(obj.id, { title: 'New title' }, if: { version: 1 })
      end.to change { document_class.find(obj.id).title }.to('New title')

      obj = document_class.create(title: 'Old title', version: 1)
      expect do
        result = document_class.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
      end.not_to change { document_class.find(obj.id).title }
    end

    it 'creates new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.upsert('not-existed-id', title: 'Title')
      end.to change { document_class.count }

      obj = document_class.find('not-existed-id')
      expect(obj.title).to eq 'Title'
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.upsert(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.upsert(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.upsert(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end
  end

  context '.reload' do
    let(:address) { Address.create }
    let(:message) { Message.create(text: 'Nice, supporting datetime range!', time: Time.now.to_datetime) }
    let(:tweet) { tweet = Tweet.create(tweet_id: 'x', group: 'abc') }

    it 'reflects persisted changes' do
      address.update_attributes(city: 'Chicago')
      expect(address.reload.city).to eq 'Chicago'
    end

    it 'uses a :consistent_read' do
      expect(Tweet).to receive(:find).with(tweet.hash_key, range_key: tweet.range_value, consistent_read: true).and_return(tweet)
      tweet.reload
    end

    it 'works with range key' do
      expect(tweet.reload.group).to eq 'abc'
    end

    it 'uses dumped value of sort key to load document' do
      klass = new_class do
        range :activated_at, :datetime
        field :name
      end

      obj = klass.create!(activated_at: Time.now, name: 'Old value')
      obj2 = klass.where(id: obj.id, activated_at: obj.activated_at).first
      obj2.update_attributes(name: 'New value')

      expect { obj.reload }.to change {
        obj.name
      }.from('Old value').to('New value')
    end
  end

  it 'has default table options' do
    address = Address.create

    expect(address.id).to_not be_nil
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
    expect(Address.hash_key).to eq :id
    expect(Address.read_capacity).to eq 100
    expect(Address.write_capacity).to eq 20
  end

  it 'follows any table options provided to it' do
    tweet = Tweet.create(group: 12_345)

    expect { tweet.id }.to raise_error(NoMethodError)
    expect(tweet.tweet_id).to_not be_nil
    expect(Tweet.table_name).to eq 'dynamoid_tests_twitters'
    expect(Tweet.hash_key).to eq :tweet_id
    expect(Tweet.read_capacity).to eq 200
    expect(Tweet.write_capacity).to eq 200
  end

  shared_examples 'it has equality testing and hashing' do
    it 'is equal to itself' do
      expect(document).to eq document
    end

    it 'is equal to another document with the same key(s)' do
      expect(document).to eq same
    end

    it 'is not equal to another document with different key(s)' do
      expect(document).to_not eq different
    end

    it 'is not equal to an object that is not a document' do
      expect(document).to_not eq 'test'
    end

    it 'is not equal to nil' do
      expect(document).to_not eq nil
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

      expect(document).to_not eq different
    end
  end

  context 'single table inheritance' do
    it 'should have a type' do
      expect(Vehicle.new.type).to eq 'Vehicle'
    end

    it 'reports the same table name for both base and derived classes' do
      expect(Vehicle.table_name).to eq Car.table_name
      expect(Vehicle.table_name).to eq NuclearSubmarine.table_name
    end
  end

  context '#count' do
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
end
