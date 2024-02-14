# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.upsert' do
  include_context 'transaction_write'

  context 'upserts' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'with class constructed in transaction' do
        obj3_id = SecureRandom.uuid
        described_class.execute do |txn|
          txn.upsert klass, { id: obj3_id, name: 'threethree' }
        end
        obj3_found = klass.find(obj3_id)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
      end

      it 'requires hash key in class' do
        expect {
          described_class.execute do |txn|
            txn.upsert klass, { name: 'threethree' }
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      before do
        klass_with_composite_key.create_table
      end

      it 'with class constructed in transaction' do
        obj3_id = SecureRandom.uuid
        described_class.execute do |txn|
          txn.upsert klass_with_composite_key, { id: obj3_id, age: 3, name: 'threethree' }
        end
        obj3_found = klass_with_composite_key.find(obj3_id, range_key: 3)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
      end

      it 'with class constructed in transaction with return value' do
        obj4_written = false
        described_class.execute do |txn|
          obj4_written = txn.upsert klass_with_composite_key, { id: SecureRandom.uuid, age: 4, name: 'fourfour' }
        end
        expect(obj4_written).to be true
      end

      it 'requires hash key in class' do
        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, { name: 'threethree' }
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires range key in class' do
        expect {
          described_class.execute do |txn|
            txn.upsert klass_with_composite_key, { id: 'bananas', name: 'threethree' }
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end

    it 'updates timestamps by class when existing' do
      klass.create_table
      obj3 = klass.create!(name: 'three', created_at: Time.now - 48.hours, updated_at: Time.now - 24.hours)
      described_class.execute do |txn|
        txn.upsert klass, { id: obj3.id, name: 'threethree' }
      end
      obj3_found = klass.find(obj3.id)
      expect(obj3_found.created_at.to_f).to be < (Time.now - 47.hours).to_f
      expect(obj3_found.updated_at.to_f).to be_within(1.seconds).of Time.now.to_f
    end

    it 'updates timestamps by class when not existing' do
      klass.create_table
      obj3_id = SecureRandom.uuid
      described_class.execute do |txn|
        txn.upsert klass, { id: obj3_id, name: 'threethree' }
      end
      obj3_found = klass.find(obj3_id)
      expect(obj3_found.created_at).to be_nil
      expect(obj3_found.updated_at.to_f).to be_within(1.seconds).of Time.now.to_f
    end

    context 'adds' do
      it 'to nil' do
        klass.create_table
        obj3_id = SecureRandom.uuid
        described_class.execute do |txn|
          txn.upsert klass, { id: obj3_id, name: 'threethree' } do |u|
            u.add(record_count: 5)
          end
        end
        obj3_found = klass.find(obj3_id)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
        expect(obj3_found.record_count).to eql(5)
      end

      it 'to a value' do
        klass.create_table
        obj3_id = SecureRandom.uuid
        klass.create!(id: obj3_id, name: 'three', record_count: 50)
        described_class.execute do |txn|
          txn.upsert klass, { id: obj3_id, name: 'threethree' } do |u|
            u.add(record_count: 5)
          end
        end
        obj3_found = klass.find(obj3_id)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
        expect(obj3_found.record_count).to eql(55)
      end

      it 'to nil set' do
        klass.create_table
        obj3_id = SecureRandom.uuid
        described_class.execute do |txn|
          txn.upsert klass, { id: obj3_id, name: 'threethree' } do |u|
            u.add(favorite_names: %w[adam bob])
          end
        end
        obj3_found = klass.find(obj3_id)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
        expect(obj3_found.favorite_names).to eql(Set.new(%w[adam bob]))
      end

      it 'to existing set' do
        klass.create_table
        obj3_id = SecureRandom.uuid
        klass.create!(id: obj3_id, name: 'three', favorite_numbers: [1, 2])
        described_class.execute do |txn|
          txn.upsert klass, { id: obj3_id, name: 'threethree' } do |u|
            u.add(favorite_numbers: [2, 3])
          end
        end
        obj3_found = klass.find(obj3_id)
        expect(obj3_found.id).to eql(obj3_id)
        expect(obj3_found.name).to eql('threethree')
        expect(obj3_found.favorite_numbers).to eql(Set[1, 2, 3])
      end
    end
  end
end
