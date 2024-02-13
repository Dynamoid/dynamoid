# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.put' do # 'put' is actually an update
  include_context 'transaction_write'

  # a 'put' is a create that overwrites existing records if present
  context 'puts' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'fails without skip_existence_check' do
        obj1 = klass.create!(name: 'one')
        expect {
          described_class.execute do |txn|
            txn.create! klass, id: obj1.id, name: 'oneo'
          end
        }.to raise_exception(Aws::DynamoDB::Errors::TransactionCanceledException)
      end

      it 'can overwrite with attributes' do
        obj1 = klass.create!(name: 'one')
        expect(klass.find(obj1.id)).to eql(obj1) # it was created
        described_class.execute do |txn|
          txn.create! klass, { id: obj1.id, name: 'oneone' }, { skip_existence_check: true }
        end
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone') # overwritten
      end

      it 'can overwrite with instance' do
        obj1 = klass.create!(name: 'one')
        expect(klass.find(obj1.id)).to eql(obj1) # it was created
        described_class.execute do |txn|
          # this use is infrequent, normal entry is from save!(obj, options)
          txn.create! klass.new(id: obj1.id, name: 'oneone'), {}, { skip_existence_check: true }
        end
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone') # overwritten
      end
    end

    context 'composite key' do
      before do
        klass_with_composite_key.create_table
      end

      it 'fails without skip_existence_check' do
        obj1 = klass_with_composite_key.create!(name: 'one', age: 1)
        expect {
          described_class.execute do |txn|
            txn.create! klass_with_composite_key, id: obj1.id, age: 1, name: 'oneo'
          end
        }.to raise_exception(Aws::DynamoDB::Errors::TransactionCanceledException)
      end

      it 'can overwrite with attributes' do
        obj1 = klass_with_composite_key.create!(name: 'one', age: 1)
        obj2 = nil
        described_class.execute do |txn|
          txn.create! klass_with_composite_key, { id: obj1.id, age: 1, name: 'oneone' },
                      { skip_existence_check: true }
          obj2 = txn.create! klass_with_composite_key, id: obj1.id, age: 2, name: 'two'
        end
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        obj2_found = klass_with_composite_key.find(obj1.id, range_key: 2)
        expect(obj1_found).to eql(obj1)
        expect(obj2_found).to eql(obj2)
        expect(obj1_found.name).to eql('oneone')
        expect(obj2_found.name).to eql('two')
      end

      it 'can overwrite with instance' do
        obj1 = klass_with_composite_key.create!(name: 'one', age: 1)
        obj2 = nil
        described_class.execute do |txn|
          # this use is infrequent, normal entry is from save!(obj, options)
          txn.create! klass_with_composite_key.new(id: obj1.id, age: 1, name: 'oneone'), {},
                      { skip_existence_check: true }
          obj2 = txn.create! klass_with_composite_key.new(id: obj1.id, age: 2, name: 'two')
        end
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        obj2_found = klass_with_composite_key.find(obj1.id, range_key: 2)
        expect(obj1_found).to eql(obj1)
        expect(obj2_found).to eql(obj2)
        expect(obj1_found.name).to eql('oneone')
        expect(obj2_found.name).to eql('two')
      end
    end
  end
end
