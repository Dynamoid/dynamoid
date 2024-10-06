# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.destroy' do
  include_context 'transaction_write'

  context 'destroys' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'with instance' do
        obj1 = klass.create!(name: 'one')
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1.persisted?).to eql(true)
        expect(obj1).not_to be_destroyed
        described_class.execute do |txn|
          txn.destroy! obj1
        end
        expect(obj1.destroyed?).to eql(true)
        expect(obj1.persisted?).to eql(false)
        expect(klass).not_to exist(obj1.id)
      end

      it 'with id' do
        obj2 = klass.create!(name: 'two')
        obj2_found = klass.find(obj2.id)
        expect(obj2_found).to eql(obj2)
        described_class.execute do |txn|
          txn.destroy! klass, obj2.id
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
        obj2 = klass_with_composite_key.create!(name: 'two', age: 2)
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        expect(obj1_found).to eql(obj1)
        described_class.execute do |txn|
          txn.destroy! obj1
        end
        expect(klass_with_composite_key).not_to exist({ id: obj1.id, age: 1 })
      end

      it 'with id' do
        obj2 = klass_with_composite_key.create!(name: 'two', age: 2)
        obj2_found = klass_with_composite_key.find(obj2.id, range_key: 2)
        expect(obj2_found).to eql(obj2)
        described_class.execute do |txn|
          txn.destroy! klass_with_composite_key, { id: obj2.id, age: 2 }
        end
        expect(klass_with_composite_key).not_to exist({ id: obj2.id, age: 1 })
      end

      it 'requires hash key' do
        expect {
          described_class.execute do |txn|
            txn.destroy! klass_with_composite_key, age: 5
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey) # not ArgumentError
      end

      it 'requires range key' do
        expect {
          described_class.execute do |txn|
            txn.destroy! klass_with_composite_key, id: 'bananas'
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey) # not ArgumentError
      end
    end

    it 'uses callbacks' do
      klass_with_callbacks.create_table
      obj1 = klass_with_callbacks.create!(name: 'one')
      expect {
        described_class.execute do |txn|
          txn.destroy! obj1
        end
      }.to output('destroying destroyed ').to_stdout
    end

    it 'uses around callbacks' do
      klass_with_around_callbacks.create_table
      obj1 = klass_with_around_callbacks.create!(name: 'one')
      expect {
        described_class.execute do |txn|
          txn.destroy! obj1
        end
      }.to output('destroying destroyed ').to_stdout
    end

    context 'when an issue detected on the DynamoDB side' do
      it 'does not roll back the changes when item to delete with specified id does not exist' do
        obj1 = klass.create!(name: 'one', id: '1')
        obj1.id = 'not-existing'
        obj2 = klass.new(name: 'two', id: '2')

        expect {
          described_class.execute do |txn|
            txn.destroy obj1
            txn.create obj2
          end
        }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

        expect(klass.count).to eql 1
        expect(klass.all.to_a.map(&:id)).to contain_exactly('1')

        # expect(obj1.destroyed?).to eql nil # FIXME
        expect(obj2.persisted?).to eql false
      end
    end

    # TODO: test destroy! vs. destroy i.e. when an :abort is raised in a callback
  end
end
