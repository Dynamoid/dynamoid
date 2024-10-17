# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.save' do
  include_context 'transaction_write'

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

      obj = klass.new(name: 'two')

      expect {
        described_class.execute do |txn|
          txn.save obj_deleted
          txn.create obj
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

      expect(klass.count).to eql 0
      # expect(obj1.changed?).to eql true # FIXME
      expect(obj.persisted?).to eql false
    end
  end

  # TODO test each callback separately
  describe 'callabacks' do
    it 'uses callbacks' do
      klass_with_callbacks.create_table
      expect {
        described_class.execute do |txn|
          txn.save! klass_with_callbacks.new(name: 'two')
        end
      }.to output('validating validated saving creating created saved ').to_stdout
    end

    it 'uses around callbacks' do
      klass_with_around_callbacks.create_table
      expect {
        described_class.execute do |txn|
          txn.save! klass_with_around_callbacks.new(name: 'two')
        end
      }.to output('saving creating created saved ').to_stdout
    end
  end
end

describe Dynamoid::TransactionWrite, '.save!' do
  include_context 'transaction_write'

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

    it 'returns self when model valid' do
      obj = klass_with_validation.new(name: 'oneone')
      expect(obj.valid?).to eql true

      result = nil
      described_class.execute do |txn|
        result = txn.save!(obj)
      end

      expect(result).to equal obj
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
