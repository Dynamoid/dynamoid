# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dynamoid::Transactions::Mutation, '#import' do
  let(:klass) do
    new_class do
      field :city
    end
  end

  it 'creates multiple items' do
    klass.create_table

    expect do
      described_class.execute do |t|
        t.import(klass, [{ city: 'Chicago' }, { city: 'New York' }])
      end
    end.to change(klass, :count).by(2)
  end

  it 'returns created items' do
    klass.create_table

    addresses = nil
    described_class.execute do |t|
      addresses = t.import(klass, [{ city: 'Chicago' }, { city: 'New York' }])
    end

    expect(addresses[0].city).to eq('Chicago')
    expect(addresses[1].city).to eq('New York')
  end

  it 'skips validations' do
    klass = new_class do
      field :city
      validates :city, presence: true
    end
    klass.create_table

    addresses = nil
    described_class.execute do |t|
      addresses = t.import(klass, [{ city: nil }, { city: 'Chicago' }])
    end

    expect(addresses[0].persisted?).to be true
    expect(addresses[1].persisted?).to be true
  end

  describe 'callbacks' do
    it 'skips validation callbacks' do
      klass = new_class do
        field :city
        validates :city, presence: true

        before_validation { ScratchPad << 'run before_validation' }
        after_validation { ScratchPad << 'run after_validation' }
      end
      klass.create_table
      ScratchPad.record []

      described_class.execute do |t|
        t.import(klass, [{ city: 'Chicago' }])
      end
      expect(ScratchPad.recorded).to be_empty
    end

    it 'skips save callbacks' do
      klass = new_class do
        field :city
        before_save { ScratchPad << 'run before_save' }
        after_save { ScratchPad << 'run after_save' }
      end
      klass.create_table
      ScratchPad.record []

      described_class.execute do |t|
        t.import(klass, [{ city: 'Chicago' }])
      end
      expect(ScratchPad.recorded).to be_empty
    end

    it 'skips create callbacks' do
      klass = new_class do
        field :city
        before_create { ScratchPad << 'run before_create' }
        after_create { ScratchPad << 'run after_create' }
      end
      klass.create_table
      ScratchPad.record []

      described_class.execute do |t|
        t.import(klass, [{ city: 'Chicago' }])
      end
      expect(ScratchPad.recorded).to be_empty
    end

    it 'runs after_commit callbacks for each model' do
      klass = new_class do
        after_commit { ScratchPad << "after_commit #{id}" }
      end
      klass.create_table
      ScratchPad.record []

      described_class.execute do |t|
        t.import(klass, [{ id: '1' }, { id: '2' }])
      end

      expect(ScratchPad.recorded).to contain_exactly('after_commit 1', 'after_commit 2')
    end

    it 'runs after_rollback callbacks for each model when exception is raised and aborts a transaction' do
      klass = new_class do
        after_rollback { ScratchPad << "after_rollback #{id}" }
      end
      klass.create_table
      ScratchPad.record []

      begin
        described_class.execute do |t|
          t.import(klass, [{ id: '3' }, { id: '4' }])
          raise 'error'
        end
      rescue => e # rubocop:disable Style/RescueStandardError
        expect(e.message).to eq('error')
      end

      expect(ScratchPad.recorded).to contain_exactly('after_rollback 3', 'after_rollback 4')
    end

    it 'runs after_rollback callbacks for each model when a transaction is rolled back' do
      klass_with_callback = new_class do
        after_rollback { ScratchPad << "after_rollback #{id}" }
      end
      klass_with_callback.create_table
      klass.create_table
      ScratchPad.record []
      klass.create(id: '1')

      begin
        described_class.execute do |t|
          t.import(klass_with_callback, [{ id: '5' }, { id: '6' }])
          t.create klass, id: '1' # triggers rollback
        end
      rescue Aws::DynamoDB::Errors::TransactionCanceledException
        # ignore
      end

      expect(ScratchPad.recorded).to contain_exactly('after_rollback 5', 'after_rollback 6')
    end
  end

  describe 'primary key validation' do
    it 'raises MissingHashKey if partition key is nil' do
      klass.create_table
      allow(SecureRandom).to receive(:uuid).and_return(nil)

      expect do
        described_class.execute do |t|
          t.import(klass, [{}])
        end
      end.to raise_error(Dynamoid::Errors::MissingHashKey)
    end

    it 'raises MissingRangeKey if sort key is nil' do
      klass_with_range = new_class do
        range :age, :integer
      end
      klass_with_range.create_table

      expect do
        described_class.execute do |t|
          t.import(klass_with_range, [{ id: '1' }])
        end
      end.to raise_error(Dynamoid::Errors::MissingRangeKey)
    end
  end

  it 'supports empty containers in serialized fields' do
    klass_with_serialized = new_class do
      field :favorite_colors, :serialized
    end
    klass_with_serialized.create_table

    user = nil
    described_class.execute do |t|
      user, = t.import(klass_with_serialized, [{ favorite_colors: Set.new }])
    end

    expect(user.reload.favorite_colors).to eq Set.new
  end

  it 'supports empty arrays' do
    klass_with_array = new_class do
      field :todo_list, :array
    end
    klass_with_array.create_table

    user = nil
    described_class.execute do |t|
      user, = t.import(klass_with_array, [{ todo_list: [] }])
    end

    expect(user.reload.todo_list).to eq []
  end

  it 'saves empty Set as nil' do
    klass_with_set = new_class do
      field :tags, :set
    end
    klass_with_set.create_table

    tweet = nil
    described_class.execute do |t|
      tweet, = t.import(klass_with_set, [{ tags: Set[] }])
    end

    expect(tweet.reload.tags).to eq nil
  end

  it 'saves empty strings as nil' do
    klass.create_table

    address = nil
    described_class.execute do |t|
      address, = t.import(klass, [{ city: '' }])
    end

    expect(address.reload.city).to eq nil
  end

  it 'saves empty strings as nil when store_empty_string_as_nil is true', config: { store_empty_string_as_nil: true } do
    klass.create_table

    address = nil
    described_class.execute do |t|
      address, = t.import(klass, [{ city: '' }])
    end

    expect(address.reload.city).to eq nil
  end

  it 'saves empty strings as is when store_empty_string_as_nil is false', config: { store_empty_string_as_nil: false } do
    klass.create_table

    address = nil
    described_class.execute do |t|
      address, = t.import(klass, [{ city: '' }])
    end

    expect(address.reload.city).to eq ''
    expect(raw_attributes(address)[:city]).to eql ''
  end

  it 'saves nil attributes' do
    klass.create_table

    address = nil
    described_class.execute do |t|
      address, = t.import(klass, [{ city: nil }])
    end

    expect(address.reload.city).to eq nil
  end

  it 'supports nil containers' do
    klass_with_array = new_class do
      field :todo_list, :array
    end
    klass_with_array.create_table

    obj = nil
    described_class.execute do |t|
      obj, = t.import(klass_with_array, [{ todo_list: nil }])
    end

    expect(obj.reload.todo_list).to eq nil
  end

  describe 'timestamps' do
    let(:klass) do
      new_class
    end

    before do
      klass.create_table
    end

    it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      travel 1.hour do
        time_now = Time.now
        obj = nil
        described_class.execute do |t|
          obj, = t.import(klass, [{}])
        end

        expect(obj.created_at.to_i).to eql(time_now.to_i)
        expect(obj.updated_at.to_i).to eql(time_now.to_i)
      end
    end

    it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      travel 1.hour do
        created_at = updated_at = Time.now
        obj = nil
        described_class.execute do |t|
          obj, = t.import(klass, [{ created_at: created_at, updated_at: updated_at }])
        end

        expect(obj.created_at.to_i).to eql(created_at.to_i)
        expect(obj.updated_at.to_i).to eql(updated_at.to_i)
      end
    end

    it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
      expect do
        described_class.execute do |t|
          t.import(klass, [{}])
        end
      end.to change(klass, :count).by(1)
    end
  end

  it 'dumps attribute values' do
    klass = new_class do
      field :active, :boolean, store_as_native_boolean: false
    end
    klass.create_table

    objects = nil
    described_class.execute do |t|
      objects = t.import(klass, [{ active: false }])
    end
    obj = objects[0]
    expect(raw_attributes(obj)[:active]).to eql('f')
  end

  it 'type casts attributes' do
    klass = new_class do
      field :count, :integer
    end
    klass.create_table

    objects = nil
    described_class.execute do |t|
      objects = t.import(klass, [{ count: '101' }])
    end
    obj = objects[0]
    expect(obj.attributes[:count]).to eql(101)
    expect(raw_attributes(obj)[:count]).to eql(101)
  end

  it 'marks all the attributes as not changed/dirty' do
    klass = new_class do
      field :count, :integer
    end
    klass.create_table

    objects = nil
    described_class.execute do |t|
      objects = t.import(klass, [{ count: '101' }])
    end
    obj = objects[0]
    expect(obj.changed?).to eql false
  end

  context 'with :raw field' do
    let(:klass) do
      new_class do
        field :hash, :raw
      end
    end

    before do
      klass.create_table
    end

    it 'works well with hash keys of any type' do
      a = nil
      expect do
        described_class.execute do |t|
          a, = t.import(klass, [{ hash: { 1 => :b } }])
        end
      end.to change(klass, :count).by(1)

      expect(klass.find(a.id)[:hash]).to eql('1': 'b')
    end
  end

  context 'when table arn is specified' do
    it 'uses the table ARN' do
      skip 'cannot test with dynamodb-local'
    end
  end

  # See https://github.com/Dynamoid/dynamoid/issues/885 for details
  context 'with Global Secondary Index' do
    let(:klass_with_gsi) do
      new_class do
        field :name
        field :age, :number

        global_secondary_index hash_key: :name, range_key: :age
      end
    end

    before do
      klass_with_gsi.create_table
    end

    it 'imports successfully when a GSI partition key is nil' do
      expect do
        described_class.execute do |t|
          t.import(klass_with_gsi, [{ name: nil, age: 42 }])
        end
      end.to change(klass_with_gsi, :count).by(1)

      obj = klass_with_gsi.find(klass_with_gsi.first.id)
      expect(obj.name).to eql nil
      expect(obj.age).to eql 42
    end

    it 'imports successfully when a GSI sort key is nil' do
      expect do
        described_class.execute do |t|
          t.import(klass_with_gsi, [{ name: 'Alex', age: nil }])
        end
      end.to change(klass_with_gsi, :count).by(1)

      obj = klass_with_gsi.find(klass_with_gsi.first.id)
      expect(obj.name).to eql 'Alex'
      expect(obj.age).to eql nil
    end
  end

  describe 'store_attribute_with_nil_value config option' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    before do
      klass.create_table
    end

    context 'when true', config: { store_attribute_with_nil_value: true } do
      it 'keeps document attribute with nil' do
        objects = nil
        described_class.execute do |t|
          objects = t.import(klass, [{ age: nil }])
        end
        obj = objects[0]

        expect(raw_attributes(obj)).to include(age: nil)
      end
    end

    context 'when false', config: { store_attribute_with_nil_value: false } do
      it 'does not keep document attribute with nil' do
        objects = nil
        described_class.execute do |t|
          objects = t.import(klass, [{ age: nil }])
        end
        obj = objects[0]

        # doesn't contain :age key
        expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
      end
    end

    context 'when by default', config: { store_attribute_with_nil_value: nil } do
      it 'does not keep document attribute with nil' do
        objects = nil
        described_class.execute do |t|
          objects = t.import(klass, [{ age: nil }])
        end
        obj = objects[0]

        # doesn't contain :age key
        expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
      end
    end
  end
end
