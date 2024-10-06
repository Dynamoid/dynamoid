# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '#delete(model)' do
  include_context 'transaction_write'

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
    expect(result).to eql(obj)
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
    it 'does not roll back the changes when item to delete with specified id does not exist' do
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
end

describe Dynamoid::TransactionWrite, '#delete(class, primary key)' do
  include_context 'transaction_write'

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
    it 'does not roll back the changes when item to delete with specified id does not exist' do
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
end
