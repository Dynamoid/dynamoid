# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#delete(model)' do # rubocop:disable RSpec/MultipleDescribes
  let(:klass) do
    new_class do
      field :name
    end
  end

  let(:klass_with_composite_key) do
    new_class do
      range :age, :integer
      field :name
    end
  end

  it 'deletes a model' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.delete obj
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.id)).to eql false
    expect(obj).to be_destroyed
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')
    result = nil

    described_class.execute do |txn|
      result = txn.delete obj
    end

    expect(result).to equal(obj)
  end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to change(klass, :count).by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to change(klass_with_composite_key, :count).by(-1)
      end
    end
  end

  describe 'primary key validation' do
    context 'simple primary key' do
      it 'requires partition key to be specified' do
        obj = klass.create!(name: 'one')
        obj.id = nil

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      it 'requires partition key to be specified' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)
        obj.id = nil

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)
        obj.age = nil

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'does not roll back the changes when a model to delete does not exist' do
      obj1 = klass.create!(name: 'one', id: '1')
      obj1.id = 'not-existing'
      obj2 = klass.new(name: 'two', id: '2')

      described_class.execute do |txn|
        txn.delete obj1
        txn.save obj2
      end

      expect(klass.count).to eql 2
      expect(klass.all.to_a.map(&:id)).to contain_exactly('1', '2')

      expect(obj1).to be_destroyed
      expect(obj2).to be_persisted
    end
  end

  it 'is not marked as destroyed when the transaction rolled back' do
    obj = klass.create!

    expect {
      described_class.execute do |txn|
        txn.delete obj
        raise 'trigger rollback'
      end
    }.to raise_error('trigger rollback')

    expect(obj).not_to be_destroyed
  end

  it 'uses dumped value of partition key to delete item' do
    klass = new_class(partition_key: { name: :published_on, type: :date }) do
      field :name
    end
    obj = klass.create!(published_on: '2018-10-07'.to_date, name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.delete obj
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.published_on)).to eql false
  end

  it 'uses dumped value of sort key to delete item' do
    klass = new_class do
      range :activated_on, :date
      field :name
    end
    obj = klass.create!(activated_on: Date.today, name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.delete obj
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?([[obj.id, obj.activated_on]])).to eql false
  end

  describe 'callbacks' do
    it 'does not run any callback' do
      klass_with_callbacks = new_class do
        before_validation { ScratchPad << 'run before_validation' }
        after_validation { ScratchPad << 'run after_validation' }

        before_create { ScratchPad << 'run before_create' }
        after_create { ScratchPad << 'run after_create' }
        around_create :around_create_callback

        before_save { ScratchPad << 'run before_save' }
        after_save { ScratchPad << 'run after_save' }
        around_save :around_save_callback

        before_destroy { ScratchPad << 'run before_destroy' }
        after_destroy { ScratchPad << 'run after_destroy' }
        around_destroy :around_destroy_callback

        def around_create_callback
          ScratchPad << 'start around_create'
          yield
          ScratchPad << 'finish around_create'
        end

        def around_save_callback
          ScratchPad << 'start around_save'
          yield
          ScratchPad << 'finish around_save'
        end

        def around_destroy_callback
          ScratchPad << 'start around_destroy'
          yield
          ScratchPad << 'finish around_destroy'
        end
      end

      ScratchPad.record []
      obj = klass_with_callbacks.create!
      ScratchPad.clear

      described_class.execute do |txn|
        txn.delete obj
      end

      expect(ScratchPad.recorded).to eql([])
    end
  end
end

describe Dynamoid::TransactionWrite, '#delete(class, primary key)' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  let(:klass_with_composite_key) do
    new_class do
      range :age, :integer
      field :name
    end
  end

  it 'deletes a model and accepts a model class and primary key' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.delete klass, obj.id
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  it 'returns nil' do
    obj = klass.create!(name: 'one')

    result = true
    described_class.execute do |txn|
      result = txn.delete klass, obj.id
    end

    expect(result).to eql nil
  end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.delete klass, obj.id
          end
        }.to change(klass, :count).by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, obj.id, obj.age
          end
        }.to change(klass_with_composite_key, :count).by(-1)
      end

      it 'raises MissingHashKey if partition key is not specified' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, nil, 5
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'raises MissingRangeKey if sort key is not specified' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, 'foo', nil
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'does not roll back the changes when a model to delete does not exist' do
      obj_to_delete = klass.create!(name: 'one', id: '1')
      obj_to_delete.id = 'not-existing'
      obj_to_save = klass.new(name: 'two', id: '2')

      described_class.execute do |txn|
        txn.delete klass, obj_to_delete.id
        txn.save obj_to_save
      end

      expect(klass.count).to eql 2
      expect(klass.all.to_a.map(&:id)).to contain_exactly('1', '2')

      expect(obj_to_delete).not_to be_destroyed
      expect(obj_to_save).to be_persisted
    end
  end

  it 'uses dumped value of partition key to delete item' do
    klass = new_class(partition_key: { name: :published_on, type: :date }) do
      field :name
    end
    obj = klass.create!(published_on: '2018-10-07'.to_date, name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.delete klass, obj.published_on
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.published_on)).to eql false
  end

  it 'uses dumped value of sort key to delete item' do
    klass = new_class do
      range :activated_on, :date
      field :name
    end
    obj = klass.create!(activated_on: Date.today, name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.delete klass, obj.id, obj.activated_on
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?([[obj.id, obj.activated_on]])).to eql false
  end

  describe 'callbacks' do
    it 'does not run any callback' do
      klass_with_callbacks = new_class do
        before_validation { ScratchPad << 'run before_validation' }
        after_validation { ScratchPad << 'run after_validation' }

        before_create { ScratchPad << 'run before_create' }
        after_create { ScratchPad << 'run after_create' }
        around_create :around_create_callback

        before_save { ScratchPad << 'run before_save' }
        after_save { ScratchPad << 'run after_save' }
        around_save :around_save_callback

        before_destroy { ScratchPad << 'run before_destroy' }
        after_destroy { ScratchPad << 'run after_destroy' }
        around_destroy :around_destroy_callback

        def around_create_callback
          ScratchPad << 'start around_create'
          yield
          ScratchPad << 'finish around_create'
        end

        def around_save_callback
          ScratchPad << 'start around_save'
          yield
          ScratchPad << 'finish around_save'
        end

        def around_destroy_callback
          ScratchPad << 'start around_destroy'
          yield
          ScratchPad << 'finish around_destroy'
        end
      end

      ScratchPad.record []
      obj = klass_with_callbacks.create!
      ScratchPad.clear

      described_class.execute do |txn|
        txn.delete klass_with_callbacks, obj.id
      end

      expect(ScratchPad.recorded).to eql([])
    end
  end
end
