# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.create' do
  include_context 'transaction_write'

  it 'persists a new model and accepts model class and attributes' do
    klass.create_table

    expect {
      described_class.execute do |txn|
        txn.create klass, name: 'three'
      end
    }.to change { klass.count }.by(1)

    obj = klass.last
    expect(obj.name).to eql('three')
  end

  it 'returns a new model' do
    klass.create_table

    obj = nil
    described_class.execute do |txn|
      obj = txn.create klass, name: 'three'
    end

    expect(obj).to be_a(klass)
    expect(obj).to be_persisted
    expect(obj.name).to eql 'three'
  end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists a model' do
        klass.create_table

        expect {
          described_class.execute do |txn|
            txn.create klass, name: 'three'
          end
        }.to change { klass.count }.by(1)
      end
    end

    context 'composite key' do
      it 'persists a model' do
        klass_with_composite_key.create_table

        expect {
          described_class.execute do |txn|
            txn.create klass_with_composite_key, name: 'three', age: 3
          end
        }.to change { klass_with_composite_key.count }.by(1)
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
          obj = txn.create klass, name: 'three'
        end

        expect(obj.created_at.to_i).to eql(time_now.to_i)
        expect(obj.updated_at.to_i).to eql(time_now.to_i)
      end
    end

    it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      travel 1.hour do
        created_at = updated_at = Time.now

        obj = nil
        described_class.execute do |txn|
          obj = txn.create klass, created_at: created_at, updated_at: updated_at
        end

        expect(obj.created_at.to_i).to eql(created_at.to_i)
        expect(obj.updated_at.to_i).to eql(updated_at.to_i)
      end
    end

    it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
      expect {
        described_class.execute do |txn|
          txn.create klass
        end
      }.not_to raise_error
    end
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'persists a valid model' do
      expect {
        described_class.execute do |txn|
          txn.create(klass_with_validation, name: 'oneone')
        end
      }.to change { klass_with_validation.count }.by(1)
    end

    it 'does not persist invalid model' do
      expect {
        described_class.execute do |txn|
          txn.create(klass_with_validation, name: 'one')
        end
      }.not_to change { klass_with_validation.count }
    end

    # FIXME
    #it 'still returns a new model even if it is invalid' do
    #  obj = nil
    #  described_class.execute do |txn|
    #    obj = txn.create(klass_with_validation, name: 'one')
    #  end

    #  expect(obj).to be_a(klass_with_validation)
    #  expect(obj.name).to eql 'one'
    #  expect(obj).to_not be_persisted
    #end

    it 'does not roll back the whole transaction when a model to be created is invalid' do
      obj_invalid = nil
      obj_valid = nil

      expect {
        described_class.execute do |txn|
          obj_invalid = txn.create(klass_with_validation, name: 'one')
          obj_valid = txn.create(klass_with_validation, name: 'twotwo')
        end
      }.to change { klass_with_validation.count }.by(1)

      # FIXME
      # expect(obj_invalid).to_not be_persisted
      # expect(obj_valid).to be_persisted

      # obj_valid_loaded = klass_with_validation.find(obj_valid.id)
      # expect(obj_valid_loaded.name).to eql 'twotwo'
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'rolls back the changes when id is not unique' do
      existing = klass.create!(name: 'one')

      expect {
        described_class.execute do |txn|
          txn.create! klass, name: 'one', id: existing.id
          txn.create! klass, name: 'two'
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

      expect(klass.count).to eql 1
      expect(klass.all.to_a).to eql [existing]
    end
  end

  it 'uses callbacks' do
    klass_with_callbacks.create_table
    expect {
      described_class.execute do |txn|
        txn.create! klass_with_callbacks, name: 'two'
      end
    }.to output('validating validated saving creating created saved ').to_stdout
  end

  it 'uses around callbacks' do
    klass_with_around_callbacks.create_table
    expect {
      described_class.execute do |txn|
        txn.create! klass_with_around_callbacks, name: 'two'
      end
    }.to output('saving creating created saved ').to_stdout
  end
end

describe Dynamoid::TransactionWrite, '.create!' do
  include_context 'transaction_write'

  it 'persists a new model and accepts model class and attributes' do
    klass.create_table

    expect {
      described_class.execute do |txn|
        txn.create! klass, name: 'three'
      end
    }.to change { klass.count }.by(1)

    obj = klass.last
    expect(obj.name).to eql('three')
  end

  it 'returns a new model' do
    klass.create_table

    obj = nil
    described_class.execute do |txn|
      obj = txn.create! klass, name: 'three'
    end

    expect(obj).to be_a(klass)
    expect(obj).to be_persisted
    expect(obj.name).to eql 'three'
  end

  describe 'validation' do
    before do
      klass_with_validation.create_table
    end

    it 'persists a valid model' do
      expect {
        described_class.execute do |txn|
          txn.create!(klass_with_validation, name: 'oneone')
        end
      }.to change { klass_with_validation.count }.by(1)
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
end
