# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#delete(model)' do
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

  it 'deletes a model and accepts a model itself' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.delete obj
      end
    }.to change { klass.count }.by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')

    result = nil
    described_class.execute do |txn|
      result = txn.delete obj
    end

    expect(result).to be_a(klass)
    expect(result).to equal(obj)
    # expect(result).to be_destroyed # FIXME
  end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to change { klass.count }.by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.delete obj
          end
        }.to change { klass_with_composite_key.count }.by(-1)
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

      expect(obj1.destroyed?).to eql nil
      expect(obj2.persisted?).to eql true
    end
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
    }.to change { klass.count }.by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  # FIXME
  # it 'returns a model' do
  #   obj = klass.create!(name: 'one')

  #   result = nil
  #   described_class.execute do |txn|
  #     result = txn.delete klass, obj.id
  #   end

  #   expect(result).to be_a(klass)
  #   expect(result).to eql(obj)
  #   expect(result).to be_destroyed
  # end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.delete klass, obj.id
          end
        }.to change { klass.count }.by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, id: obj.id, age: obj.age
          end
        }.to change { klass_with_composite_key.count }.by(-1)
      end

      it 'raises MissingHashKey if partition key is not specified' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, id: nil, age: 5
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'raises MissingRangeKey if sort key is not specified' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, id: 'foo', age: nil
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
        txn.delete klass, id: obj_to_delete.id
        txn.save obj_to_save
      end

      expect(klass.count).to eql 2
      expect(klass.all.to_a.map(&:id)).to contain_exactly('1', '2')

      expect(obj_to_delete.destroyed?).to eql nil
      expect(obj_to_save.persisted?).to eql true
    end
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
        txn.delete klass_with_callbacks, id: obj.id
      end

      expect(ScratchPad.recorded).to eql([])
    end
  end
end
