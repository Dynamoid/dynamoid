# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#update_attributes' do
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

  let(:klass_with_validation) do
    new_class do
      field :name
      validates :name, length: { minimum: 4 }
    end
  end

  let(:klass_with_all_callbacks) do
    new_class do
      field :name

      before_validation { ScratchPad << 'run before_validation' }
      after_validation { ScratchPad << 'run after_validation' }

      before_update { ScratchPad << 'run before_update' }
      after_update { ScratchPad << 'run after_update' }
      around_update :around_update_callback

      before_save { ScratchPad << 'run before_save' }
      after_save { ScratchPad << 'run after_save' }
      around_save :around_save_callback

      def around_update_callback
        ScratchPad << 'start around_update'
        yield
        ScratchPad << 'finish around_update'
      end

      def around_save_callback
        ScratchPad << 'start around_save'
        yield
        ScratchPad << 'finish around_save'
      end
    end
  end

  it 'persists changes' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.update_attributes obj, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj.changed?).to eql false
  end

  # TODO:
  it 'raises exception if a model is not persisted'

  # TODO:
  it 'can be called without attributes to modify'

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |txn|
            txn.update_attributes obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.update_attributes obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'timestamps' do
    it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
      obj = klass.create!

      travel 1.hour do
        time_now = Time.now

        described_class.execute do |txn|
          txn.update_attributes obj, name: 'Alex [Updated]'
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
          txn.update_attributes obj, created_at: created_at, updated_at: updated_at
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
          txn.update_attributes obj, name: 'Alex [Updated]'
        end
      }.not_to raise_error
    end

    it 'does not raise error if no changes and Config.timestamps=false', config: { timestamps: false } do
      obj = klass.create!

      expect {
        described_class.execute do |txn|
          txn.update_attributes obj, {}
        end
      }.not_to raise_error
    end
  end

  describe 'validation' do
    it 'persists a valid model' do
      obj = klass_with_validation.create!(name: 'oneone')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'twotwo'
      end

      obj_loaded = klass_with_validation.find(obj.id)
      expect(obj_loaded.name).to eql 'twotwo'

      expect(obj).to be_persisted
      expect(obj).not_to be_changed
    end

    it 'does not persist invalid model' do
      obj = klass_with_validation.create!(name: 'oneone')

      expect {
        described_class.execute do |txn|
          txn.update_attributes obj, name: 'one'
        end
      }.not_to change { klass_with_validation.find(obj.id).name }

      expect(obj.name).to eql 'one'
      expect(obj).to be_persisted
      expect(obj).to be_changed
    end

    it 'returns true when model valid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update_attributes(obj, name: 'oneone [Updated]')
      end

      expect(result).to eql true
    end

    it 'returns false when model invalid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update_attributes(obj, name: 'one')
      end

      expect(result).to eql false
    end

    it 'does not roll back the whole transaction when a model to be saved is invalid' do
      obj_invalid = klass_with_validation.create!(name: 'oneone')
      obj_valid = klass_with_validation.create!(name: 'twotwo')

      described_class.execute do |txn|
        txn.update_attributes obj_invalid, name: 'one'
        txn.update_attributes obj_valid, name: 'twotwotwo'
      end

      expect(obj_valid.reload.name).to eql 'twotwotwo'
      expect(obj_invalid.reload.name).to eql 'oneone'
    end
  end

  it 'aborts updating and returns false if callback throws :abort' do
    klass = new_class do
      before_update { throw :abort }
    end
    obj = klass.create!(name: 'Alex')

    result = nil
    expect {
      described_class.execute do |txn|
        result = txn.update_attributes obj, name: 'Alex [Updated]'
      end
    }.not_to change { klass.count }

    expect(result).to eql false
  end

  it 'does not roll back the transaction when a model updating aborted by a callback' do
    klass = new_class do
      before_update { throw :abort }
    end

    obj_to_update = klass.create!(name: 'Alex')
    obj_to_save = klass.new

    expect {
      described_class.execute do |txn|
        txn.save obj_to_save
        txn.update_attributes obj_to_update, name: 'Alex [Updated]'
      end
    }.to change { klass.count }.by(1)

    expect(obj_to_save).to be_persisted
    expect(klass.exists?(obj_to_save.id)).to eql true
    expect(obj_to_update).not_to be_changed
  end

  it 'does not raise exception and does not roll back the transaction when a model to update does not exist anymore' do
    obj_deleted = klass.create!(name: 'Alex')
    klass.find(obj_deleted.id).delete
    obj_deleted.name = 'Alex [updated]'
    obj_to_create = nil

    expect {
      described_class.execute do |txn|
        txn.update_attributes obj_deleted, name: 'Alex [Updated]'
        obj_to_create = txn.create klass, name: 'Michael'
      end
    }.to change { klass.count }.by(2)

    expect(obj_to_create).to be_persisted
    expect(obj_deleted).to be_persisted
    expect(obj_deleted).not_to be_destroyed
    expect(klass.find(obj_deleted.id).name).to eql 'Alex [Updated]'
  end

  it 'is marked as changed when the transaction rolled back' do
    obj = klass.create!(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Alex [Updated]'
        raise "trigger rollback"
      end
    }.to raise_error("trigger rollback")

    expect(obj).to be_changed
  end

  describe 'callbacks' do
    before do
      ScratchPad.clear
    end

    it 'runs before_save callback' do
      klass_with_callback = new_class do
        field :name
        before_save { ScratchPad.record 'run before_save' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run before_save'
    end

    it 'runs after_save callbacks' do
      klass_with_callback = new_class do
        field :name
        after_save { ScratchPad.record 'run after_save' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run after_save'
    end

    it 'runs around_save callbacks' do
      klass_with_callback = new_class do
        field :name
        around_save :around_save_callback

        def around_save_callback
          ScratchPad << 'start around_save'
          yield
          ScratchPad << 'finish around_save'
        end
      end
      obj = klass_with_callback.create!(name: 'Alex')
      ScratchPad.record []

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql ['start around_save', 'finish around_save']
    end

    it 'runs before_validation callback' do
      klass_with_callback = new_class do
        field :name
        before_validation { ScratchPad.record 'run before_validation' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run before_validation'
    end

    it 'runs after_validation callback' do
      klass_with_callback = new_class do
        field :name
        after_validation { ScratchPad.record 'run after_validation' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run after_validation'
    end

    it 'runs before_update callback' do
      klass_with_callback = new_class do
        field :name
        before_update { ScratchPad.record 'run before_update' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run before_update'
    end

    it 'runs after_update callback' do
      klass_with_callback = new_class do
        field :name
        after_update { ScratchPad.record 'run after_update' }
      end

      obj = klass_with_callback.create!(name: 'Alex')

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql 'run after_update'
    end

    it 'runs around_update callback' do
      klass_with_callback = new_class do
        field :name
        around_update :around_update_callback

        def around_update_callback
          ScratchPad << 'start around_update'
          yield
          ScratchPad << 'finish around_update'
        end
      end
      obj = klass_with_callback.create!(name: 'Alex')
      ScratchPad.clear

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql ['start around_update', 'finish around_update']
    end

    it 'runs callbacks in the proper order' do
      obj = klass_with_all_callbacks.create!(name: 'John')
      ScratchPad.clear

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'
      end

      expect(ScratchPad.recorded).to eql [ # rubocop:disable Style/StringConcatenation
                                           'run before_validation',
                                           'run after_validation',
                                           'run before_save',
                                           'start around_save',
                                           'run before_update',
                                           'start around_update',
                                           'finish around_update',
                                           'run after_update',
                                           'finish around_save',
                                           'run after_save'
      ]
    end

    it 'runs callbacks immediately' do
      obj = klass_with_all_callbacks.create!(name: 'John')
      ScratchPad.clear
      callbacks = nil

      described_class.execute do |txn|
        txn.update_attributes obj, name: 'Bob'

        callbacks = ScratchPad.recorded.dup
        ScratchPad.clear
      end

      expect(callbacks).to contain_exactly(
        'run before_validation',
        'run after_validation',
        'run before_save',
        'start around_save',
        'run before_update',
        'start around_update',
        'finish around_update',
        'run after_update',
        'finish around_save',
        'run after_save'
      )
      expect(ScratchPad.recorded).to eql []
    end
  end
end

describe Dynamoid::TransactionWrite, '#update_attributes!' do
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

  let(:klass_with_validation) do
    new_class do
      field :name
      validates :name, length: { minimum: 4 }
    end
  end

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.update_attributes! obj, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj.changed?).to eql false
  end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |txn|
            txn.update_attributes! obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.update_attributes! obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'returns true when model valid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update_attributes!(obj, name: 'oneone [UPDATED]')
      end

      expect(result).to eql true
    end

    it 'returns true when model valid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update_attributes!(obj, name: 'oneone [Updated]')
      end

      expect(result).to eql true
    end

    it 'raise DocumentNotValid when model invalid' do
      obj = klass_with_validation.create!(name: 'oneone')

      expect {
        described_class.execute do |txn|
          txn.update_attributes! obj, name: 'one'
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)
    end

    it 'rolls back the whole transaction when a model to be saved is invalid' do
      obj_invalid = klass_with_validation.create!(name: 'oneone')
      obj_valid = klass_with_validation.create!(name: 'twotwo')

      expect {
        described_class.execute do |txn|
          txn.update_attributes! obj_invalid, name: 'one'
          txn.update_attributes! obj_valid, name: 'twotwotwo'
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)

      expect(obj_valid.reload.name).to eql 'twotwo'
      expect(obj_invalid.reload.name).to eql 'oneone'
    end
  end

  it 'aborts updating and raises exception if callback throws :abort' do
    klass = new_class do
      field :name
      before_update { throw :abort }
    end
    obj = klass.create!(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.update_attributes! obj, name: 'Alex [Updated]'
      end
    }.to raise_error(Dynamoid::Errors::RecordNotSaved)

    expect(klass.find(obj.id).name).to eql 'Alex'
  end

  it 'rolls back the transaction when a model updating aborted by a callback' do
    klass = new_class do
      field :name
      before_update { throw :abort }
    end

    obj_to_update = klass.create!(name: 'Alex')
    obj_to_save = klass.new

    expect {
      expect {
        described_class.execute do |txn|
          txn.save obj_to_save
          txn.update_attributes! obj_to_update, name: 'Alex [Updated]'
        end
      }.to raise_error(Dynamoid::Errors::RecordNotSaved)
    }.not_to change { klass.count }

    expect(obj_to_save).not_to be_persisted
    expect(obj_to_update.changed?).to eql true
  end

  it 'does not raise exception and does not roll back the transaction when a model to update does not exist anymore' do
    obj_deleted = klass.create!(name: 'Alex')
    klass.find(obj_deleted.id).delete
    obj_deleted.name = 'Alex [updated]'
    obj_to_create = nil

    expect {
      described_class.execute do |txn|
        txn.update_attributes! obj_deleted, name: 'Alex [Updated]'
        obj_to_create = txn.create klass, name: 'Michael'
      end
    }.to change { klass.count }.by(2)

    expect(obj_to_create).to be_persisted
    expect(obj_deleted).to be_persisted
    expect(obj_deleted).not_to be_destroyed
    expect(klass.find(obj_deleted.id).name).to eql 'Alex [Updated]'
  end
end
