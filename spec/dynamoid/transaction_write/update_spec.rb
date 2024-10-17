# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.update(class, attributes)' do # => .update_fields
  include_context 'transaction_write'

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.update klass, id: obj.id, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    # expect(obj.changed?).to eql false # FIXME
  end

  # FIXME
  # it 'returns nil' do
  #   obj = klass.create!(name: 'Alex')

  #   result = true
  #   described_class.execute do |txn|
  #     result = txn.update klass, id: obj.id, name: 'Alex [Updated]'
  #   end

  #   expect(result).to eql nil
  # end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |txn|
            txn.update klass, id: obj.id, name: 'Alex [Updated]'
          end
        }.to change { klass.find(obj.id).name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.update klass_with_composite_key, id: obj.id, age: obj.age, name: 'Alex [Updated]'
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
          txn.update klass, id: obj.id, name: 'Alex [Updated]'
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
          txn.update klass, id: obj.id, created_at: created_at, updated_at: updated_at
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
          txn.update klass, id: obj.id, name: 'Alex [Updated]'
        end
      }.not_to raise_error
    end
  end

  # FIXME
  #context 'when an issue detected on the DynamoDB side' do
  #  it 'rolls back the changes when model does not exist' do
  #    obj1 = klass.create!(name: 'one')
  #    klass.find(obj1.id).delete
  #    obj2 = klass.new(name: 'two')

  #    expect {
  #      described_class.execute do |txn|
  #        txn.update klass, {id: obj1.id, name: 'one [updated]' }
  #        txn.create obj2
  #      end
  #    }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

  #    expect(klass.count).to eql 0
  #    expect(obj1.changed?).to eql true # FIXME
  #    expect(obj2.persisted?).to eql false
  #  end
  #end
end

describe Dynamoid::TransactionWrite, '.update(model, attributes)' do # => update_attributes
  include_context 'transaction_write'

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.update obj, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj.changed?).to eql false
  end

  # FIXME:
  # it 'returns true' do
  #   klass.create_table
  #   obj = klass.create!(name: 'Alex')

  #   result = nil
  #   described_class.execute do |txn|
  #     result = txn.update(obj, name: 'Alex [Updated]')
  #   end

  #   expect(result).to eql true
  # end

  # TODO:
  it 'raises exception if a model is not persisted'

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |txn|
            txn.update obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.update obj, name: 'Alex [Updated]'
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
          txn.update obj, name: 'Alex [Updated]'
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
          txn.update obj, created_at: created_at, updated_at: updated_at
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
          txn.update obj, name: 'Alex [Updated]'
        end
      }.not_to raise_error
    end
  end

  describe 'validation' do
    it 'persists a valid model' do
      obj = klass_with_validation.create!(name: 'oneone')

      described_class.execute do |txn|
        txn.update obj, name: 'twotwo'
      end

      obj_loaded = klass_with_validation.find(obj.id)
      expect(obj_loaded.name).to eql 'twotwo'
    end

    it 'does not persist invalid model' do
      obj = klass_with_validation.create!(name: 'oneone')

      expect {
        described_class.execute do |txn|
          txn.update obj, name: 'one'
        end
      }.not_to change { obj.reload.name }

      # expect(obj.name).to eql 'one' # FIXME
      # expect(obj.changed?).to eql true # FIXME
    end

    it 'returns false when model invalid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update(obj, name: 'one')
      end

      expect(result).to eql false
    end

    it 'does not roll back the whole transaction when a model to be saved is invalid' do
      obj_invalid = klass_with_validation.create!(name: 'oneone')
      obj_valid = klass_with_validation.create!(name: 'twotwo')

      described_class.execute do |txn|
        txn.update obj_invalid, name: 'one'
        txn.update obj_valid, name: 'twotwotwo'
      end

      expect(obj_valid.reload.name).to eql 'twotwotwo'
      expect(obj_invalid.reload.name).to eql 'oneone'
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'rolls back the changes when a model does not exist anymore' do
      obj_deleted = klass.create!(name: 'one')
      klass.find(obj_deleted.id).delete
      obj_deleted.name = 'one [updated]'

      obj = klass.new(name: 'two')

      expect {
        described_class.execute do |txn|
          txn.update obj_deleted, name: 'one [updated]'
          txn.create obj
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

      expect(klass.count).to eql 0
      # expect(obj_deleted.changed?).to eql true # FIXME
      expect(obj.persisted?).to eql false
    end
  end

  describe 'callbacks' do
    it 'uses callbacks' do
      klass_with_callbacks.create_table
      obj1 = klass_with_callbacks.create!(name: 'one')
      expect {
        described_class.execute do |txn|
          obj1.name = 'oneone'
          txn.update! obj1
        end
      }.to output('validating validated saving updating updated saved ').to_stdout
    end

    it 'uses around callbacks' do
      klass_with_around_callbacks.create_table
      obj1 = klass_with_around_callbacks.create!(name: 'one')
      expect {
        described_class.execute do |txn|
          obj1.name = 'oneone'
          txn.update! obj1
        end
      }.to output('saving updating updated saved ').to_stdout
    end
  end
end

describe Dynamoid::TransactionWrite, '.update!(model, attributes)' do # => update_attributes!
  include_context 'transaction_write'

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |txn|
      txn.update! obj, name: 'Alex [Updated]'
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
            txn.update! obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |txn|
            txn.update! obj, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'returns self when model valid' do
      obj = klass_with_validation.create!(name: 'oneone')

      result = nil
      described_class.execute do |txn|
        result = txn.update!(obj, name: 'oneone [UPDATED]')
      end

      expect(result).to equal obj
    end

    it 'raise DocumentNotValid when model invalid' do
      obj = klass_with_validation.create!(name: 'oneone')

      expect {
        described_class.execute do |txn|
          txn.update! obj, name: 'one'
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)
    end

    it 'rolls back the whole transaction when a model to be saved is invalid' do
      obj_invalid = klass_with_validation.create!(name: 'oneone')
      obj_valid = klass_with_validation.create!(name: 'twotwo')

      expect {
        described_class.execute do |txn|
          txn.update! obj_invalid, name: 'one'
          txn.update! obj_valid, name: 'twotwotwo'
        end
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)

      expect(obj_valid.reload.name).to eql 'twotwo'
      expect(obj_invalid.reload.name).to eql 'oneone'
    end
  end
end
