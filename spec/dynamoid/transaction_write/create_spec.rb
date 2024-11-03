# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '.create' do
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
      before_validation { ScratchPad << 'run before_validation' }
      after_validation { ScratchPad << 'run after_validation' }

      before_create { ScratchPad << 'run before_create' }
      after_create { ScratchPad << 'run after_create' }
      around_create :around_create_callback

      before_save { ScratchPad << 'run before_save' }
      after_save { ScratchPad << 'run after_save' }
      around_save :around_save_callback

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
    end
  end

  it 'persists a new model' do
    klass.create_table

    expect {
      described_class.execute do |txn|
        txn.create klass, name: 'Alex'
      end
    }.to change { klass.count }.by(1)

    obj = klass.last
    expect(obj.name).to eql 'Alex'
  end

  it 'returns a new model' do
    klass.create_table

    obj = nil
    described_class.execute do |txn|
      obj = txn.create klass, name: 'Alex'
    end

    expect(obj).to be_a(klass)
    expect(obj).to be_persisted
    expect(obj.name).to eql 'Alex'
  end

  it 'creates multiple documents' do
    klass.create_table
    result = nil

    expect {
      described_class.execute do |txn|
        result = txn.create klass, [{ name: 'Alex' }, { name: 'Michael' }]
      end
    }.to change { klass.count }.by(2)

    expect(klass.pluck(:name)).to contain_exactly('Alex', 'Michael')
    expect(result.size).to eq 2
    expect(result).to be_all { |obj| obj.is_a? klass }
    expect(result).to be_all(&:persisted?)
    expect(result.map(&:name)).to contain_exactly('Alex', 'Michael')
  end

  context 'when a block specified' do
    it 'calls a block and passes a model as argument' do
      klass.create_table
      obj = nil

      described_class.execute do |txn|
        obj = txn.create klass, { name: 'Alex' } do |u|
          u.name += " [Updated]"
        end
      end

      expect(obj.name).to eql 'Alex [Updated]'
    end

    it 'calls a block and passes each model as argument if there are multiple models' do
      klass.create_table
      objects = nil

      described_class.execute do |txn|
        objects = txn.create klass, [{ name: 'Alex' }, { name: 'Michael' }] do |u|
          u.name += " [Updated]"
        end
      end

      expect(objects.map(&:name)).to contain_exactly('Alex [Updated]', 'Michael [Updated]')
    end
  end

  # TODO:
  it 'can be called without attributes to modify'

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists a model' do
        klass.create_table

        expect {
          described_class.execute do |txn|
            txn.create klass, name: 'Alex'
          end
        }.to change { klass.count }.by(1)
      end
    end

    context 'composite key' do
      it 'persists a model' do
        klass_with_composite_key.create_table

        expect {
          described_class.execute do |txn|
            txn.create klass_with_composite_key, name: 'Alex', age: 3
          end
        }.to change { klass_with_composite_key.count }.by(1)
      end
    end
  end

  describe 'primary key validation' do
    context 'composite key' do
      it 'requires sort key to be specified' do
        klass_with_composite_key.create_table

        expect {
          described_class.execute do |txn|
            txn.create klass_with_composite_key, name: 'Alex', age: nil
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  describe 'timestamps' do
    before do
      klass.create_table
    end

    it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      travel 1.hour do
        time_now = Time.now

        obj = nil
        described_class.execute do |txn|
          obj = txn.create klass, name: 'Alex'
        end

        expect(obj.created_at.to_i).to eql time_now.to_i
        expect(obj.updated_at.to_i).to eql time_now.to_i
      end
    end

    it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      travel 1.hour do
        created_at = updated_at = Time.now

        obj = nil
        described_class.execute do |txn|
          obj = txn.create klass, created_at: created_at, updated_at: updated_at
        end

        expect(obj.created_at.to_i).to eql created_at.to_i
        expect(obj.updated_at.to_i).to eql updated_at.to_i
      end
    end

    it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
      expect {
        described_class.execute do |txn|
          txn.create klass, name: 'Alex'
        end
      }.not_to raise_error
    end

    it 'does not raise error if no changes and Config.timestamps=false', config: { timestamps: false } do
      expect {
        described_class.execute do |txn|
          txn.create klass, {}
        end
      }.not_to raise_error
    end
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'persists a valid model' do
      obj = nil

      expect {
        described_class.execute do |txn|
          obj = txn.create(klass_with_validation, name: 'oneone')
        end
      }.to change { klass_with_validation.count }.by(1)

      expect(obj).to be_persisted
      expect(obj).not_to be_changed
    end

    it 'does not persist invalid model' do
      obj = nil

      expect {
        described_class.execute do |txn|
          obj = txn.create(klass_with_validation, name: 'one')
        end
      }.not_to change { klass_with_validation.count }

      expect(obj).not_to be_persisted
      expect(obj).to be_changed
    end

    it 'returns a new model even if it is invalid' do
      obj = nil
      described_class.execute do |txn|
        obj = txn.create(klass_with_validation, name: 'one')
      end

      expect(obj).to be_a(klass_with_validation)
      expect(obj.name).to eql 'one'
      expect(obj).to_not be_persisted
    end

    it 'does not roll back the whole transaction when a model to be created is invalid' do
      obj_invalid = nil
      obj_valid = nil

      expect {
        described_class.execute do |txn|
          obj_invalid = txn.create(klass_with_validation, name: 'one')
          obj_valid = txn.create(klass_with_validation, name: 'twotwo')
        end
      }.to change { klass_with_validation.count }.by(1)

      expect(obj_invalid).to_not be_persisted
      expect(obj_valid).to be_persisted

      obj_valid_loaded = klass_with_validation.find(obj_valid.id)
      expect(obj_valid_loaded.name).to eql 'twotwo'
    end
  end

  it 'aborts creation and returns false if callback throws :abort' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass = new_class do
      field :name
      before_create { throw :abort }
    end
    klass.create_table
    obj = nil

    expect {
      described_class.execute do |txn|
        obj = txn.create klass, name: 'Alex'
      end
    }.not_to change { klass.count }

    expect(obj).not_to be_persisted
    expect(obj).to be_changed
  end

  it 'does not roll back the transaction when a model creation aborted by a callback' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass_with_callback = new_class do
      field :name
      before_create { throw :abort }
    end
    klass = new_class do
      field :name
    end
    klass_with_callback.create_table
    klass.create_table

    obj_to_save = klass.new(name: 'Michael')
    obj_to_create = nil

    expect {
      described_class.execute do |txn|
        txn.save obj_to_save
        obj_to_create = txn.create klass_with_callback, name: 'Alex'
      end
    }.to change { klass.count }.by(1)

    expect(obj_to_save).to be_persisted
    expect(klass.exists?(obj_to_save.id)).to eql true
    expect(obj_to_create).not_to be_persisted
    expect(obj_to_create).to be_changed
  end

  it 'rolls back the transaction when id is not unique' do
    existing = klass.create!(name: 'Alex')

    expect {
      described_class.execute do |txn|
        txn.create klass, name: 'Alex', id: existing.id
        txn.create klass, name: 'Michael'
      end
    }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

    expect(klass.count).to eql 1
    expect(klass.all.to_a).to eql [existing]
  end

  it 'is not marked as persisted and is marked as changed when the transaction rolled back' do
    obj = nil

    expect {
      described_class.execute do |txn|
        obj = txn.create klass, name: 'Alex'
        raise "trigger rollback"
      end
    }.to raise_error("trigger rollback")

    expect(obj).not_to be_persisted
    expect(obj).to be_changed
  end

  describe 'callbacks' do
    before do
      ScratchPad.clear
    end

    it 'runs before_create callback' do
      klass_with_callback = new_class do
        before_create { ScratchPad.record 'run before_create' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql 'run before_create'
    end

    it 'runs after_create callback' do
      klass_with_callback = new_class do
        after_create { ScratchPad.record 'run after_create' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
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

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql ['start around_create', 'finish around_create']
    end

    it 'runs before_save callback' do
      klass_with_callback = new_class do
        before_save { ScratchPad.record 'run before_save' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql 'run before_save'
    end

    it 'runs after_save callbacks' do
      klass_with_callback = new_class do
        after_save { ScratchPad.record 'run after_save' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql 'run after_save'
    end

    it 'runs around_save callback' do
      klass_with_callback = new_class do
        around_save :around_save_callback

        def around_save_callback
          ScratchPad << 'start around_save'
          yield
          ScratchPad << 'finish around_save'
        end
      end

      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql ['start around_save', 'finish around_save']
    end

    it 'runs before_validation callback' do
      klass_with_callback = new_class do
        before_validation { ScratchPad.record 'run before_validation' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql 'run before_validation'
    end

    it 'runs after_validation callback' do
      klass_with_callback = new_class do
        after_validation { ScratchPad.record 'run after_validation' }
      end
      klass_with_callback.create_table

      described_class.execute do |txn|
        txn.create klass_with_callback
      end

      expect(ScratchPad.recorded).to eql 'run after_validation'
    end

    it 'runs callbacks in the proper order' do
      klass_with_all_callbacks.create_table

      described_class.execute do |txn|
        txn.create klass_with_all_callbacks
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
      callbacks = nil

      described_class.execute do |txn|
        txn.create klass_with_all_callbacks

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
end

describe Dynamoid::TransactionWrite, '.create!' do
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

    expect {
      described_class.execute do |txn|
        txn.create! klass, name: 'Alex'
      end
    }.to change { klass.count }.by(1)

    obj = klass.last
    expect(obj.name).to eql 'Alex'
  end

  it 'returns a new model' do
    klass.create_table

    obj = nil
    described_class.execute do |txn|
      obj = txn.create! klass, name: 'Alex'
    end

    expect(obj).to be_a(klass)
    expect(obj).to be_persisted
    expect(obj.name).to eql 'Alex'
  end

  it 'creates multiple documents' do
    klass.create_table
    result = nil

    expect {
      described_class.execute do |txn|
        result = txn.create! klass, [{ name: 'Alex' }, { name: 'Michael' }]
      end
    }.to change { klass.count }.by(2)

    expect(klass.pluck(:name)).to contain_exactly('Alex', 'Michael')
    expect(result.size).to eq 2
    expect(result).to be_all { |obj| obj.is_a? klass }
    expect(result).to be_all(&:persisted?)
    expect(result.map(&:name)).to contain_exactly('Alex', 'Michael')
  end

  context 'when a block specified' do
    it 'calls a block and passes a model as argument' do
      klass.create_table
      obj = nil

      described_class.execute do |txn|
        obj = txn.create! klass, { name: 'Alex' } do |u|
          u.name += " [Updated]"
        end
      end

      expect(obj.name).to eql 'Alex [Updated]'
    end

    it 'calls a block and passes each model as argument if there are multiple models' do
      klass.create_table
      objects = nil

      described_class.execute do |txn|
        objects = txn.create! klass, [{ name: 'Alex' }, { name: 'Michael' }] do |u|
          u.name += " [Updated]"
        end
      end

      expect(objects.map(&:name)).to contain_exactly('Alex [Updated]', 'Michael [Updated]')
    end
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'persists a valid model' do
      obj = nil

      expect {
        described_class.execute do |txn|
          obj = txn.create!(klass_with_validation, name: 'oneone')
        end
      }.to change { klass_with_validation.count }.by(1)

      expect(obj).to be_persisted
      expect(obj).not_to be_changed
    end

    it 'raise DocumentNotValid when invalid model' do
      expect {
        described_class.execute do |txn|
          txn.create!(klass_with_validation, name: 'one')
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)
    end

    it 'rolls back the whole transaction when a model to be created is invalid' do
      expect {
        expect {
          described_class.execute do |txn|
            txn.create!(klass_with_validation, name: 'twotwo')
            txn.create!(klass_with_validation, name: 'one')
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
      }.to_not change { klass_with_validation.count }
    end
  end

  it 'aborts creation and raises exception if callback throws :abort' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass = new_class do
      field :name
      before_create { throw :abort }
    end
    klass.create_table

    expect {
      expect {
        described_class.execute do |txn|
          txn.create! klass, name: 'Alex'
        end
      }.to raise_error(Dynamoid::Errors::RecordNotSaved)
    }.not_to change { klass.count }
  end

  it 'rolls back the transaction when a model creation aborted by a callback' do
    if ActiveSupport.version < Gem::Version.new('5.0')
      skip "Rails 4.x and below don't support aborting with `throw :abort`"
    end

    klass_with_callback = new_class do
      field :name
      before_create { throw :abort }
    end
    klass = new_class do
      field :name
    end
    klass_with_callback.create_table
    klass.create_table

    obj_to_save = klass.new(name: 'Michael')

    expect {
      expect {
        described_class.execute do |txn|
          txn.save obj_to_save
          txn.create! klass_with_callback, name: 'Alex'
        end
      }.to raise_error(Dynamoid::Errors::RecordNotSaved)
    }.not_to change { klass.count }

    expect(obj_to_save).not_to be_persisted
    expect(obj_to_save).to be_changed
  end
end
