# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '.upsert' do
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

  it 'persists a new model if primary key does not exist yet' do
    klass.create_table

    id_new = SecureRandom.uuid
    obj = klass.new(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.upsert klass, id_new, name: 'Alex'
      end
    }.to change(klass, :count).by(1)

    obj = klass.find(id_new)
    expect(obj.name).to eql 'Alex'
  end

  it 'persists changes of already existing model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.upsert klass, obj.id, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
  end

  it 'returns nil' do
    obj = klass.create!(name: 'Alex')

    result = true
    described_class.execute do |txn|
      result = txn.upsert klass, obj.id, name: 'Alex [Updated]'
    end

    expect(result).to eql nil
  end

  it 'cannot be called without attributes to modify' do
    obj = klass.create!(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.upsert klass, obj.id
      end
    }.to raise_error(ArgumentError)
  end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists a new model' do
        klass.create_table
        id_new = SecureRandom.uuid

        expect {
          described_class.execute do |txn|
            txn.upsert klass, id_new, {}
          end
        }.to change(klass, :count).by(1)
      end

      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |txn|
            txn.upsert klass, obj.id, name: 'Alex [Updated]'
          end
        }.to change { klass.find(obj.id).name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists a new model' do
        klass_with_composite_key.create_table
        id_new = SecureRandom.uuid

        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, id_new, 3, {}
          end
        }.to change(klass_with_composite_key, :count).by(1)
      end

      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, obj.id, obj.age, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'primary key validation' do
    context 'simple primary key' do
      it 'requires partition key to be specified' do
        expect {
          described_class.execute do |txn|
            txn.upsert klass, nil, { name: 'threethree' }
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      it 'requires partition key to be specified' do
        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, nil, name: 'Alex'
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        id_new = SecureRandom.uuid

        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, id_new, nil, name: 'Alex'
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  describe 'timestamps' do
    context 'new model' do
      it 'sets updated_at only if Config.timestamps=true', config: { timestamps: true } do
        klass.create_table
        id_new = SecureRandom.uuid

        travel 1.hour do
          time_now = Time.now

          described_class.execute do |txn|
            txn.upsert klass, id_new, {}
          end

          obj = klass.find(id_new)
          expect(obj.updated_at.to_i).to eql time_now.to_i
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        klass.create_table
        id_new = SecureRandom.uuid

        travel 1.hour do
          created_at = updated_at = Time.now

          described_class.execute do |txn|
            txn.upsert klass, id_new, created_at: created_at, updated_at: updated_at
          end

          obj = klass.find(id_new)
          expect(obj.created_at.to_i).to eql created_at.to_i
          expect(obj.updated_at.to_i).to eql updated_at.to_i
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        klass.create_table

        expect {
          described_class.execute do |txn|
            txn.upsert klass, SecureRandom.uuid, name: 'Alex'
          end
        }.not_to raise_error
      end

      it 'does not raise error if no changes and Config.timestamps=false', config: { timestamps: false } do
        klass.create_table

        expect {
          described_class.execute do |txn|
            txn.upsert klass, SecureRandom.uuid, {}
          end
        }.not_to raise_error
      end
    end

    context 'already created model' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create!

        travel 1.hour do
          time_now = Time.now

          described_class.execute do |txn|
            txn.upsert klass, obj.id, name: 'Alex [Updated]'
          end

          obj.reload
          expect(obj.updated_at.to_i).to eql time_now.to_i
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create!

        travel 1.hour do
          created_at = updated_at = Time.now

          described_class.execute do |txn|
            txn.upsert klass, obj.id, created_at: created_at, updated_at: updated_at
          end

          obj.reload
          expect(obj.created_at.to_i).to eql created_at.to_i
          expect(obj.updated_at.to_i).to eql updated_at.to_i
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create!

        expect {
          described_class.execute do |txn|
            txn.upsert klass, obj.id, name: 'Alex [Updated]'
          end
        }.not_to raise_error
      end

      it 'does not raise error if no changes and Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create!

        expect {
          described_class.execute do |txn|
            txn.upsert klass, obj.id, {}
          end
        }.not_to raise_error
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    # TODO: support conditions
    it 'rolls back the changes when a specified condition is not satisfied'
  end

  describe 'callbacks' do
    it 'does not run any callback' do
      klass_with_callbacks = new_class do
        field :name

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
      obj = klass_with_callbacks.create!(name: 'Alex')
      ScratchPad.clear

      described_class.execute do |txn|
        txn.upsert klass_with_callbacks, obj.id, name: 'Alex [Updated]'
      end

      expect(ScratchPad.recorded).to eql([])
    end
  end
end
