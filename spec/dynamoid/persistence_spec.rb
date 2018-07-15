# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Persistence do
  let(:address) { Address.new }

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid.adapter.delete_table(Address.table_name) if Dynamoid.adapter.list_tables.include?(Address.table_name)
      end

      it 'creates a table' do
        Address.create_table(table_name: Address.table_name)

        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(table_name: Address.table_name)

        expect(Address.table_exists?(Address.table_name)).to be_truthy
        expect(Address.table_exists?('crazytable')).to be_falsey
      end
    end
  end

  describe 'delete_table' do
    it 'deletes the table' do
      Address.create_table
      Address.delete_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(Address.table_name)).to be_falsey
    end
  end

  describe 'record deletion' do
    let(:klass) do
      Class.new do
        include Dynamoid::Document
        table name: :addresses
        field :city

        before_destroy do |_i|
          # Halting the callback chain in active record changed with Rails >= 5.0.0.beta1
          # We now have to throw :abort to halt the callback chain
          # See: https://github.com/rails/rails/commit/bb78af73ab7e86fd9662e8810e346b082a1ae193
          if ActiveModel::VERSION::MAJOR < 5
            false
          else
            throw :abort
          end
        end
      end
    end

    describe 'destroy' do
      it 'deletes an item completely' do
        @user = User.create(name: 'Josh')
        @user.destroy

        expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
      end

      it 'returns false when destroy fails (due to callback)' do
        a = klass.create!
        expect(a.destroy).to eql false
        expect(klass.first.id).to eql a.id
      end
    end

    describe 'destroy!' do
      it 'deletes the item' do
        address.save!
        address.destroy!
        expect(Address.count).to eql 0
      end

      it 'raises exception when destroy fails (due to callback)' do
        a = klass.create!
        expect { a.destroy! }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
      end
    end
  end

  it 'assigns itself an id on save' do
    address.save

    expect(Dynamoid.adapter.read('dynamoid_tests_addresses', address.id)[:id]).to eq address.id
  end

  it 'prevents concurrent writes to tables with a lock_version' do
    address.save!
    a1 = address
    a2 = Address.find(address.id)

    a1.city = 'Seattle'
    a2.city = 'San Francisco'

    a1.save!
    expect { a2.save! }.to raise_exception(Dynamoid::Errors::StaleObjectError)
  end

  it 'assigns itself an id on save only if it does not have one' do
    address.id = 'test123'
    address.save

    expect(Dynamoid.adapter.read('dynamoid_tests_addresses', 'test123')).to_not be_empty
  end

  it 'has a table name' do
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
  end

  context 'with namespace is empty' do
    def reload_address
      Object.send(:remove_const, 'Address')
      load 'app/models/address.rb'
    end

    namespace = Dynamoid::Config.namespace

    before do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = ''
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = namespace
      end
    end

    it 'does not add a namespace prefix to table names' do
      table_name = Address.table_name
      expect(Dynamoid::Config.namespace).to be_empty
      expect(table_name).to eq 'addresses'
    end
  end

  context 'with timestamps set to false' do
    def reload_address
      Object.send(:remove_const, 'Address')
      load 'app/models/address.rb'
    end

    timestamps = Dynamoid::Config.timestamps

    before do
      reload_address
      Dynamoid.configure do |config|
        config.timestamps = false
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.timestamps = timestamps
      end
    end

    it 'sets nil to created_at and updated_at' do
      address = Address.create
      expect(address.created_at).to be_nil
      expect(address.updated_at).to be_nil
    end
  end

  it 'deletes an item completely' do
    @user = User.create(name: 'Josh')
    @user.destroy

    expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
  end

  it 'runs the before_create callback only once' do
    expect_any_instance_of(CamelCase).to receive(:doing_before_create).once.and_return(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #create' do
    expect_any_instance_of(CamelCase).to receive(:doing_after_create).once.and_return(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #save' do
    expect_any_instance_of(CamelCase).to receive(:doing_after_create).once.and_return(true)

    CamelCase.new.save
  end

  it 'works with a HashWithIndifferentAccess' do
    hash = ActiveSupport::HashWithIndifferentAccess.new('city' => 'Atlanta')

    expect { Address.create(hash) }.to_not raise_error
  end

  context 'create' do
    {
      Tweet   => ['with range',    { tweet_id: 1, group: 'abc' }],
      Message => ['without range', { message_id: 1, text: 'foo', time: DateTime.now }]
    }.each_pair do |clazz, fields|
      it "checks for existence of an existing object #{fields[0]}" do
        t1 = clazz.new(fields[1])
        t2 = clazz.new(fields[1])

        t1.save
        expect do
          t2.save!
        end.to raise_exception Dynamoid::Errors::RecordNotUnique
      end
    end
  end

  describe 'save' do
    it 'creates table if it does not exist' do
      klass = Class.new do
        include Dynamoid::Document
        table name: :foo_bars
      end

      expect { klass.create }.not_to raise_error(Aws::DynamoDB::Errors::ResourceNotFoundException)
      expect(klass.create.id).to be_present
    end
  end

  context 'update' do
    before :each do
      @tweet = Tweet.create(tweet_id: 1, group: 'abc', count: 5, tags: Set.new(%w[db sql]), user_name: 'john')
    end

    it 'runs before_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_before_update).once.and_return(true)

      CamelCase.create(color: 'blue').update do |t|
        t.set(color: 'red')
      end
    end

    it 'runs after_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_after_update).once.and_return(true)

      CamelCase.create(color: 'blue').update do |t|
        t.set(color: 'red')
      end
    end

    it 'support add/delete operation on a field' do
      @tweet.update do |t|
        t.add(count: 3)
        t.delete(tags: Set.new(['db']))
      end

      expect(@tweet.count).to eq(8)
      expect(@tweet.tags.to_a).to eq(['sql'])
    end

    it 'checks the conditions on update' do
      result = @tweet.update(if: { count: 5 }) do |t|
        t.add(count: 3)
      end
      expect(result).to be_truthy

      expect(@tweet.count).to eq(8)

      result = @tweet.update(if: { count: 5 }) do |t|
        t.add(count: 3)
      end
      expect(result).to be_falsey

      expect(@tweet.count).to eq(8)

      expect do
        @tweet.update!(if: { count: 5 }) do |t|
          t.add(count: 3)
        end
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'prevents concurrent saves to tables with a lock_version' do
      address.save!
      a2 = Address.find(address.id)
      a2.update! { |a| a.set(city: 'Chicago') }

      expect do
        address.city = 'Seattle'
        address.save!
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end
  end

  context 'delete' do
    it 'deletes model with datetime range key' do
      expect do
        msg = Message.create!(message_id: 1, time: DateTime.now, text: 'Hell yeah')
        msg.destroy
      end.to_not raise_error
    end

    context 'with lock version' do
      it 'deletes a record if lock version matches' do
        address.save!
        expect { address.destroy }.to_not raise_error
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.destroy }.to raise_exception(Dynamoid::Errors::StaleObjectError)
      end

      it 'uses the correct lock_version even if it is modified' do
        address.save!
        a1 = address
        a1.lock_version = 100

        expect { a1.destroy }.to_not raise_error
      end
    end
  end

  context 'single table inheritance' do
    let(:vehicle) { Vehicle.create }
    let(:car) { Car.create(power_locks: false) }
    let(:sub) { NuclearSubmarine.create(torpedoes: 5) }

    it 'saves subclass objects in the parent table' do
      c = car
      expect(Vehicle.find(c.id)).to eq c
    end

    it 'loads subclass item when querying the parent table' do
      c = car
      s = sub

      Vehicle.all.to_a.tap do |v|
        expect(v).to include(c)
        expect(v).to include(s)
      end
    end

    it 'does not load parent item when quering the child table' do
      vehicle && car

      expect(Car.all).to contain_exactly(car)
      expect(Car.all).not_to include(vehicle)
    end

    it 'does not load items of sibling class' do
      car && sub

      expect(Car.all).to contain_exactly(car)
      expect(Car.all).not_to include(sub)
    end
  end

  describe '.import' do
    before do
      Address.create_table
      User.create_table
      Tweet.create_table
    end

    it 'creates multiple documents' do
      expect do
        Address.import([{ city: 'Chicago' }, { city: 'New York' }])
      end.to change { Address.count }.by(2)
    end

    it 'returns created documents' do
      addresses = Address.import([{ city: 'Chicago' }, { city: 'New York' }])
      expect(addresses[0].city).to eq('Chicago')
      expect(addresses[1].city).to eq('New York')
    end

    it 'does not validate documents' do
      klass = Class.new do
        include Dynamoid::Document
        field :city
        validates :city, presence: true

        def self.name
          'Address'
        end
      end

      addresses = klass.import([{ city: nil }, { city: 'Chicago' }])
      expect(addresses[0].persisted?).to be true
      expect(addresses[1].persisted?).to be true
    end

    it 'does not run callbacks' do
      klass = Class.new do
        include Dynamoid::Document
        field :city
        validates :city, presence: true

        def self.name
          'Address'
        end

        before_save { raise 'before save callback called' }
      end

      expect { klass.import([{ city: 'Chicago' }]) }.not_to raise_error
    end

    it 'makes batch operation' do
      expect(Dynamoid.adapter).to receive(:batch_write_item).and_call_original
      Address.import([{ city: 'Chicago' }, { city: 'New York' }])
    end

    it 'supports empty containers in `serialized` fields' do
      users = User.import([name: 'Philip', favorite_colors: Set.new])

      user = User.find(users[0].id)
      expect(user.favorite_colors).to eq Set.new
    end

    it 'supports array being empty' do
      users = User.import([{ todo_list: [] }])

      user = User.find(users[0].id)
      expect(user.todo_list).to eq []
    end

    it 'saves empty set as nil' do
      tweets = Tweet.import([{ group: 'one', tags: [] }])

      tweet = Tweet.find_by_tweet_id(tweets[0].tweet_id)
      expect(tweet.tags).to eq nil
    end

    it 'saves empty string as nil' do
      users = User.import([{ name: '' }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'saves attributes with nil value' do
      users = User.import([{ name: nil }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'supports container types being nil' do
      users = User.import([{ name: 'Philip', todo_list: nil }])

      user = User.find(users[0].id)
      expect(user.todo_list).to eq nil
    end

    context 'backoff is specified' do
      let(:backoff_strategy) do
        ->(_) { -> { @counter += 1 } }
      end

      before do
        @old_backoff = Dynamoid.config.backoff
        @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

        @counter = 0
        Dynamoid.config.backoff_strategies[:simple] = backoff_strategy
        Dynamoid.config.backoff = { simple: nil }
      end

      after do
        Dynamoid.config.backoff = @old_backoff
        Dynamoid.config.backoff_strategies = @old_backoff_strategies
      end

      it 'creates multiple documents' do
        expect do
          Address.import([{ city: 'Chicago' }, { city: 'New York' }])
        end.to change { Address.count }.by(2)
      end

      it 'uses specified backoff when some items are not processed' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        items = (1..3).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        klass.import(items)
        expect(@counter).to eq 2
      end

      it 'uses new backoff after successful call without unprocessed items' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        # batch_write_item processes up to 15 items at once
        # so we emulate 4 calls with items
        items = (1..50).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        expect(backoff_strategy).to receive(:call).exactly(2).times.and_call_original
        klass.import(items)
        expect(@counter).to eq 2
      end
    end
  end
end
