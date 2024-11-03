# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#destroy' do # rubocop:disable RSpec/MultipleDescribes
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

  let(:klass_with_all_callbacks) do
    new_class do
      before_destroy { ScratchPad << 'run before_destroy' }
      after_destroy { ScratchPad << 'run after_destroy' }
      around_destroy :around_destroy_callback

      def around_destroy_callback
        ScratchPad << 'start around_destroy'
        yield
        ScratchPad << 'finish around_destroy'
      end
    end
  end

  it 'deletes a model' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.destroy obj
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.id)).to eql false
    expect(obj).to be_destroyed
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')
    result = nil

    described_class.execute do |txn|
      result = txn.destroy obj
    end

    expect(result).to equal(obj)
  end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.destroy obj
          end
        }.to change(klass, :count).by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.destroy obj
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
            txn.destroy obj
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
            txn.destroy obj
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)
        obj.age = nil

        expect {
          described_class.execute do |txn|
            txn.destroy obj
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'does not raise exception and does not roll back the transaction when a model to destroy does not exist' do
      obj_to_destroy = klass.create!(name: 'one', id: '1')
      obj_to_destroy.id = 'not-existing'
      obj_to_save = klass.new(name: 'two', id: '2')

      expect {
        described_class.execute do |txn|
          txn.destroy obj_to_destroy
          txn.save obj_to_save
        end
      }.to change(klass, :count).by(1)

      expect(obj_to_destroy).to be_destroyed
      expect(obj_to_save).to be_persisted
      expect(klass.all.to_a.map(&:id)).to contain_exactly('1', obj_to_save.id)
    end
  end

  it 'aborts destroying and returns false if callback throws :abort' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass = new_class do
      before_destroy { throw :abort }
    end
    obj = klass.create!

    result = nil
    expect {
      described_class.execute do |txn|
        result = txn.destroy obj
      end
    }.not_to change { klass.count }

    expect(result).to eql false
  end

  it 'does not roll back the transaction when a destroying of some model aborted by a before_destroy callback' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass = new_class do
      before_destroy { throw :abort }
    end

    obj_to_destroy = klass.create!
    obj_to_save = klass.new

    expect {
      described_class.execute do |txn|
        txn.save obj_to_save
        txn.destroy obj_to_destroy
      end
    }.to change { klass.count }.by(1)

    expect(obj_to_save).to be_persisted
    expect(obj_to_destroy).not_to be_destroyed

    expect(klass.exists?(obj_to_destroy.id)).to eql true
    expect(klass.exists?(obj_to_save.id)).to eql true
  end

  it 'is not marked as destroyed when the transaction rolled back' do
    obj = klass.create!

    expect {
      described_class.execute do |txn|
        txn.destroy obj
        raise 'trigger rollback'
      end
    }.to raise_error('trigger rollback')

    expect(obj).not_to be_destroyed
  end

  describe 'callbacks' do
    before do
      ScratchPad.clear
    end

    it 'runs before_destroy callback' do
      klass_with_callback = new_class do
        before_destroy { ScratchPad.record 'run before_destroy' }
      end
      obj = klass_with_callback.create!

      described_class.execute do |txn|
        txn.destroy obj
      end

      expect(ScratchPad.recorded).to eql 'run before_destroy'
    end

    it 'runs after_destroy callbacks' do
      klass_with_callback = new_class do
        after_destroy { ScratchPad.record 'run after_destroy' }
      end
      obj = klass_with_callback.create!

      described_class.execute do |txn|
        txn.destroy obj
      end

      expect(ScratchPad.recorded).to eql 'run after_destroy'
    end

    it 'runs around_destroy callbacks' do
      klass_with_callback = new_class do
        around_destroy :around_destroy_callback

        def around_destroy_callback
          ScratchPad << 'start around_destroy'
          yield
          ScratchPad << 'finish around_destroy'
        end
      end
      obj = klass_with_callback.create!
      ScratchPad.clear

      described_class.execute do |txn|
        txn.destroy obj
      end

      expect(ScratchPad.recorded).to eql ['start around_destroy', 'finish around_destroy']
    end

    it 'runs callbacks in the proper order' do
      obj = klass_with_all_callbacks.create!
      ScratchPad.clear

      described_class.execute do |txn|
        txn.destroy obj
      end

      expect(ScratchPad.recorded).to eql [
        'run before_destroy',
        'start around_destroy',
        'finish around_destroy',
        'run after_destroy'
      ]
    end

    it 'runs callbacks immediately' do
      obj = klass_with_all_callbacks.create!
      ScratchPad.clear
      callbacks = nil

      described_class.execute do |txn|
        txn.destroy obj

        callbacks = ScratchPad.recorded.dup
        ScratchPad.clear
      end

      expect(callbacks).to contain_exactly(
        'run before_destroy',
        'start around_destroy',
        'finish around_destroy',
        'run after_destroy'
      )
      expect(ScratchPad.recorded).to eql []
    end

    it 'returns false if :abort is thrown' do
      if ActiveSupport.version < Gem::Version.new('5.0')
        skip "Rails 4.x and below don't support aborting with `throw :abort`"
      end

      klass_with_callback = new_class do
        before_destroy { throw :abort }
      end
      obj = klass_with_callback.create!
      result = nil

      described_class.execute do |txn|
        result = txn.destroy obj
      end

      expect(result).to eql false
    end
  end
end

describe Dynamoid::TransactionWrite, '.destroy!' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  it 'deletes a model' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.destroy! obj
      end
    }.to change(klass, :count).by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')

    result = nil
    described_class.execute do |txn|
      result = txn.destroy! obj
    end

    expect(result).to be_a(klass)
    expect(result).to equal(obj)
    expect(result).to be_destroyed
  end

  it 'aborts destroying and raises RecordNotDestroyed if callback throws :abort' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass = new_class do
      before_destroy { throw :abort }
    end
    obj = klass.create!

    expect {
      expect {
        described_class.execute do |txn|
          txn.destroy! obj
        end
      }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
    }.not_to change { klass.count }

    expect(obj.destroyed?).to eql nil
  end

  it 'does not raise exception and does not roll back the transaction when a model to destroy does not exist' do
    obj_to_destroy = klass.create!(name: 'one', id: '1')
    obj_to_destroy.id = 'not-existing'
    obj_to_save = klass.new(name: 'two', id: '2')

    expect {
      described_class.execute do |txn|
        txn.destroy! obj_to_destroy
        txn.save obj_to_save
      end
    }.to change(klass, :count).by(1)

    expect(obj_to_destroy).to be_destroyed
    expect(obj_to_save).to be_persisted

    expect(klass.all.to_a.map(&:id)).to contain_exactly('1', obj_to_save.id)
  end
end
