# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.delete' do
  include_context 'transaction_write'

  context 'deletes' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'with instance' do
        obj1 = klass.create!(name: 'one')
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        described_class.execute do |txn|
          txn.delete obj1
        end
        expect(klass).not_to exist(obj1.id)
      end

      it 'with id' do
        obj2 = klass.create!(name: 'two')
        obj2_found = klass.find(obj2.id)
        expect(obj2_found).to eql(obj2)
        described_class.execute do |txn|
          txn.delete klass, obj2.id
        end
        expect(klass).not_to exist(obj2.id)
      end
    end

    context 'composite key' do
      before do
        klass_with_composite_key.create_table
      end

      it 'with instance' do
        obj1 = klass_with_composite_key.create!(name: 'one', age: 1)
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        expect(obj1_found).to eql(obj1)
        described_class.execute do |txn|
          txn.delete obj1
        end
        expect(klass_with_composite_key).not_to exist({ id: obj1.id, age: 1 })
      end

      it 'with id' do
        obj2 = klass_with_composite_key.create!(name: 'two', age: 2)
        obj2_found = klass_with_composite_key.find(obj2.id, range_key: 2)
        expect(obj2_found).to eql(obj2)
        described_class.execute do |txn|
          txn.delete klass_with_composite_key, id: obj2.id, age: 2
        end
        expect(klass_with_composite_key).not_to exist({ id: obj2.id, age: 2 })
      end

      it 'requires hash key' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, age: 5
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires range key' do
        expect {
          described_class.execute do |txn|
            txn.delete klass_with_composite_key, id: 'bananas'
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end

    context 'when an issue detected on the DynamoDB side' do
      it 'does not roll back the changes when item to delete with specified id does not exist' do
        obj1 = klass.create!(name: 'one', id: '1')
        obj1.id = 'not-existing'
        obj2 = klass.new(name: 'two', id: '2')

        described_class.execute do |txn|
          txn.delete obj1
          txn.create obj2
        end

        expect(klass.count).to eql 2
        expect(klass.all.to_a.map(&:id)).to contain_exactly('1', '2')

        expect(obj1.destroyed?).to eql nil
        expect(obj2.persisted?).to eql true
      end
    end
  end
end
