# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '.save' do
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

      before_create { ScratchPad << 'run before_create' }
      after_create { ScratchPad << 'run after_create' }
      around_create :around_create_callback

      before_update { ScratchPad << 'run before_update' }
      after_update { ScratchPad << 'run after_update' }
      around_update :around_update_callback

      before_save { ScratchPad << 'run before_save' }
      after_save { ScratchPad << 'run after_save' }
      around_save :around_save_callback

      def around_create_callback
        ScratchPad << 'start around_create'
        yield
        ScratchPad << 'finish around_create'
      end

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

  it 'persists a new model' do
    klass.create_table
    obj = klass.new(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.save obj
      end
    }.to change { klass.count }.by(1)

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex'
    expect(obj.persisted?).to eql true
    expect(obj.changed?).to eql false
  end

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')
    obj.name = 'Alex [Updated]'

    described_class.execute do |txn|
      txn.save obj
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj.changed?).to eql false
  end

  # FIXME:
  #it 'returns true' do
  #  klass.create_table
  #  obj = klass.new(name: 'two')

  #  result = nil
  #  described_class.execute do |txn|
  #    result = txn.save obj
  #  end

  #  expect(result).to eql true
  #end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists a new model' do
        klass.create_table
        obj = klass.new

        expect {
          described_class.execute do |txn|
            txn.save obj
          end
        }.to change { klass.count }.by(1)
      end

      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          obj.name = 'Alex [Updated]'
          described_class.execute do |txn|
            txn.save obj
          end
        }.to change { klass.find(obj.id).name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists a new model' do
        klass_with_composite_key.create_table
        obj = klass_with_composite_key.new(age: 3)

        expect {
          described_class.execute do |txn|
            txn.save obj
          end
        }.to change { klass_with_composite_key.count }.by(1)
      end

      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          obj.name = 'Alex [Updated]'
          described_class.execute do |txn|
            txn.save obj
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'timestamps' do
    context 'new model' do
      before do
        klass.create_table
      end

      it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          time_now = Time.now
          obj = klass.new

          described_class.execute do |txn|
            txn.save obj
          end

          obj.reload
          expect(obj.created_at.to_i).to eql time_now.to_i
          expect(obj.updated_at.to_i).to eql time_now.to_i
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          created_at = updated_at = Time.now
          obj = klass.new(created_at: created_at, updated_at: updated_at)

          described_class.execute do |txn|
            txn.save obj
          end

          obj.reload
          expect(obj.created_at.to_i).to eql created_at.to_i
          expect(obj.updated_at.to_i).to eql updated_at.to_i
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        expect {
          described_class.execute do |txn|
            txn.save klass.new
          end
        }.not_to raise_error
      end
    end

    context 'already created model' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create!

        travel 1.hour do
          time_now = Time.now
          obj.name = 'Alex [Updated]'

          described_class.execute do |txn|
            txn.save obj
          end

          obj.reload
          expect(obj.updated_at.to_i).to eql time_now.to_i
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create!

        travel 1.hour do
          created_at = updated_at = Time.now

          obj.created_at = created_at
          obj.updated_at = updated_at

          described_class.execute do |txn|
            txn.save obj
          end

          obj.reload
          expect(obj.created_at.to_i).to eql created_at.to_i
          expect(obj.updated_at.to_i).to eql updated_at.to_i
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create!
        obj.name = 'Alex [Updated]'

        expect {
          described_class.execute do |txn|
            txn.save obj
          end
        }.not_to raise_error
      end
    end
  end

  describe 'validation' do
    context 'new model' do
      before do
        klass_with_validation.create_table
      end

      it 'persists a valid model' do
        obj = klass_with_validation.new(name: 'oneone')
        expect(obj.valid?).to eql true

        described_class.execute do |txn|
          txn.save obj
        end

        obj_loaded = klass_with_validation.find(obj.id)
        expect(obj_loaded.name).to eql 'oneone'
      end

      it 'does not persist invalid model' do
        obj = klass_with_validation.new(name: 'one')
        expect(obj.valid?).to eql false

        expect {
          described_class.execute do |txn|
            txn.save obj
          end
        }.not_to change { klass_with_validation.count }
      end

      it 'returns true when model valid' do
        obj = klass_with_validation.new(name: 'oneone')
        expect(obj.valid?).to eql true

        result = nil
        described_class.execute do |txn|
          result = txn.save(obj)
        end

        expect(result).to eql true
      end

      it 'returns false when model invalid' do
        obj = klass_with_validation.new(name: 'one')
        expect(obj.valid?).to eql false

        result = nil
        described_class.execute do |txn|
          result = txn.save(obj)
        end

        expect(result).to eql false
      end

      it 'does not roll back the whole transaction when a model to be created is invalid' do
        obj_invalid = klass_with_validation.new(name: 'one')
        obj_valid = klass_with_validation.new(name: 'twotwo')

        expect(obj_valid.valid?).to eql true
        expect(obj_invalid.valid?).to eql false

        expect {
          described_class.execute do |txn|
            txn.save obj_invalid
            txn.save obj_valid
          end
        }.to change { klass_with_validation.count }.by(1)

        expect(klass_with_validation.all.map(&:id)).to contain_exactly(obj_valid.id)
      end
    end

    context 'already persisted model' do
      it 'persists a valid model' do
        obj = klass_with_validation.create!(name: 'oneone')
        obj.name = 'twotwo'
        expect(obj.valid?).to eql true

        described_class.execute do |txn|
          txn.save obj
        end

        obj_loaded = klass_with_validation.find(obj.id)
        expect(obj_loaded.name).to eql 'twotwo'
      end

      it 'does not persist invalid model' do
        obj = klass_with_validation.create!(name: 'oneone')
        obj.name = 'one'
        expect(obj.valid?).to eql false

        expect {
          described_class.execute do |txn|
            txn.save obj
          end
        }.not_to change { klass_with_validation.count }
      end

      it 'returns true when model valid' do
        obj = klass_with_validation.create!(name: 'oneone')
        obj.name = 'oneone [Updated]'
        expect(obj.valid?).to eql true

        result = nil
        described_class.execute do |txn|
          result = txn.save obj
        end

        expect(result).to eql true
      end

      it 'returns false when model invalid' do
        obj = klass_with_validation.create!(name: 'oneone')
        obj.name = 'one'
        expect(obj.valid?).to eql false

        result = nil
        described_class.execute do |txn|
          result = txn.save obj
        end

        expect(result).to eql false
      end

      it 'does not roll back the whole transaction when a model to be saved is invalid' do
        obj_invalid = klass_with_validation.create!(name: 'oneone')
        obj_valid = klass_with_validation.create!(name: 'twotwo')

        obj_invalid.name = 'one'
        obj_valid.name = 'twotwotwo'
        expect(obj_valid.valid?).to eql true
        expect(obj_invalid.valid?).to eql false

        described_class.execute do |txn|
          txn.save obj_invalid
          txn.save obj_valid
        end

        expect(obj_valid.reload.name).to eql 'twotwotwo'
        expect(obj_invalid.reload.name).to eql 'oneone'
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'rolls back the changes when a model does not exist' do
      obj_deleted = klass.create!(name: 'one')
      klass.find(obj_deleted.id).delete
      obj_deleted.name = 'one [updated]'
      obj_to_create = nil

      expect {
        described_class.execute do |txn|
          txn.save obj_deleted
          obj_to_create = txn.create klass, name: 'two'
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

      expect(klass.count).to eql 0
      # expect(obj1.changed?).to eql true # FIXME
      expect(obj_to_create.persisted?).to eql false
    end
  end

  describe 'callbacks' do
    before do
      ScratchPad.clear
    end

    context 'new model' do
      it 'runs before_save callback' do
        klass_with_callback = new_class do
          before_save { ScratchPad.record 'run before_save' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_save'
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          after_save { ScratchPad.record 'run after_save' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run after_save'
      end

      it 'runs around_save callbacks' do
        klass_with_callback = new_class do
          around_save :around_save_callback

          def around_save_callback
            ScratchPad << 'start around_save'
            yield
            ScratchPad << 'finish around_save'
          end
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql ['start around_save', 'finish around_save']
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          before_validation { ScratchPad.record 'run before_validation' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_validation'
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          after_validation { ScratchPad.record 'run after_validation' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run after_validation'
      end

      it 'runs before_create callback' do
        klass_with_callback = new_class do
          before_create { ScratchPad.record 'run before_create' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_create'
      end

      it 'runs after_create callback' do
        klass_with_callback = new_class do
          after_create { ScratchPad.record 'run after_create' }
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run after_create'
      end

      it 'runs around_create callback' do
        klass_with_callback = new_class do
          around_create :around_create_callback

          def around_create_callback
            ScratchPad << 'start around_create'
            yield
            ScratchPad << 'finish around_create'
          end
        end

        klass_with_callback.create_table
        obj = klass_with_callback.new
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql ['start around_create', 'finish around_create']
      end

      it 'runs callbacks in the proper order' do
        klass_with_all_callbacks.create_table
        obj = klass_with_all_callbacks.new(name: 'Alex')
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql [ # rubocop:disable Style/StringConcatenation
                            'run before_validation',
                            'run after_validation',
                            'run before_save',
                            'start around_save',
                            'run before_create',
                            'start around_create',
                            'finish around_create',
                            'run after_create',
                            'finish around_save',
                            'run after_save'
        ]
      end

      it 'runs callbacks immediately' do
        klass_with_all_callbacks.create_table
        obj = klass_with_all_callbacks.new(name: 'Alex')
        callbacks = nil

        described_class.execute do |txn|
          txn.save obj

          callbacks = ScratchPad.recorded.dup
          ScratchPad.clear
        end

        expect(callbacks).to contain_exactly(
          'run before_validation',
          'run after_validation',
          'run before_save',
          'start around_save',
          'run before_create',
          'start around_create',
          'finish around_create',
          'run after_create',
          'finish around_save',
          'run after_save')
        expect(ScratchPad.recorded).to eql []
      end
    end

    context 'persisted model' do
      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name
          before_save { ScratchPad.record 'run before_save' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_save'
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          field :name
          after_save { ScratchPad.record 'run after_save' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
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
        obj.name = 'Bob'
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql ['start around_save', 'finish around_save']
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          field :name
          before_validation { ScratchPad.record 'run before_validation' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_validation'
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          field :name
          after_validation { ScratchPad.record 'run after_validation' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run after_validation'
      end

      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :name
          before_update { ScratchPad.record 'run before_update' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql 'run before_update'
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :name
          after_update { ScratchPad.record 'run after_update' }
        end

        obj = klass_with_callback.create!(name: 'Alex')
        obj.name = 'Bob'

        described_class.execute do |txn|
          txn.save obj
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
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
        end

        expect(ScratchPad.recorded).to eql ['start around_update', 'finish around_update']
      end

      it 'runs callbacks in the proper order' do
        obj = klass_with_all_callbacks.create!(name: 'John')
        obj.name = 'Bob'
        ScratchPad.record []

        described_class.execute do |txn|
          txn.save obj
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
        obj.name = 'Bob'
        ScratchPad.clear
        callbacks = nil

        described_class.execute do |txn|
          txn.save obj

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
          'run after_save')
        expect(ScratchPad.recorded).to eql []
      end
    end
  end
end

describe Dynamoid::TransactionWrite, '.save!' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  let(:klass_with_validation) do
    new_class do
      field :name
      validates :name, length: { minimum: 4 }
    end
  end

  it 'persists a new model' do
    klass.create_table
    obj = klass.new(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.save! obj
      end
    }.to change { klass.count }.by(1)

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex'
    expect(obj.persisted?).to eql true
    expect(obj.changed?).to eql false
  end

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')
    obj.name = 'Alex [Updated]'

    described_class.execute do |txn|
      txn.save! obj
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj.changed?).to eql false
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'returns true when model valid' do
      obj = klass_with_validation.new(name: 'oneone')
      expect(obj.valid?).to eql true

      result = nil
      described_class.execute do |txn|
        result = txn.save!(obj)
      end

      expect(result).to eql true
    end

    it 'raise DocumentNotValid when model invalid' do
      obj = klass_with_validation.new(name: 'one')
      expect(obj.valid?).to eql false

      expect {
        described_class.execute do |txn|
          txn.save! obj
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)
    end

    it 'rolls back the whole transaction when a model to be created is invalid' do
      obj_invalid = klass_with_validation.new(name: 'one')
      obj_valid = klass_with_validation.new(name: 'twotwo')

      expect(obj_valid.valid?).to eql true
      expect(obj_invalid.valid?).to eql false

      expect {
        expect {
          described_class.execute do |txn|
            txn.save! obj_valid
            txn.save! obj_invalid
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
      }.not_to change { klass_with_validation.count }
    end

    it 'rolls back the whole transaction when a model to be saved is invalid' do
      obj_invalid = klass_with_validation.create!(name: 'oneone')
      obj_valid = klass_with_validation.create!(name: 'twotwo')

      obj_invalid.name = 'one'
      obj_valid.name = 'twotwotwo'
      expect(obj_valid.valid?).to eql true
      expect(obj_invalid.valid?).to eql false

      expect {
        described_class.execute do |txn|
          txn.save! obj_invalid
          txn.save! obj_valid
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)

      expect(obj_valid.reload.name).to eql 'twotwo'
      expect(obj_invalid.reload.name).to eql 'oneone'
    end
  end
end
