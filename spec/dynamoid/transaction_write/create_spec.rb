# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.create' do
  include_context 'transaction_write'

  context 'creates' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'with class constructed in transaction' do
        obj3 = nil
        described_class.execute do |txn|
          obj3 = txn.create! klass, name: 'three'
        end
        obj3_found = klass.find(obj3.id)
        expect(obj3_found).to eql(obj3)
        expect(obj3_found.name).to eql('three')
      end
    end

    context 'composite key' do
      before do
        klass_with_composite_key.create_table
      end

      it 'with class constructed in transaction' do
        obj3 = nil
        described_class.execute do |txn|
          obj3 = txn.create! klass_with_composite_key, name: 'three', age: 3
        end
        obj3_found = klass_with_composite_key.find(obj3.id, range_key: 3)
        expect(obj3_found).to eql(obj3)
        expect(obj3_found.name).to eql('three')
      end
    end

    it 'creates timestamps' do
      klass.create_table
      obj1 = nil
      time_now = Time.now
      described_class.execute do |txn|
        obj1 = txn.create! klass, name: 'one'
      end
      obj1_found = klass.find(obj1.id)

      expect(obj1_found.created_at.to_f).to be_within(1.seconds).of time_now.to_f
      expect(obj1_found.updated_at.to_f).to be_within(1.seconds).of time_now.to_f

      expect(obj1.created_at.to_f).to be_within(1.seconds).of time_now.to_f
      expect(obj1.updated_at.to_f).to be_within(1.seconds).of time_now.to_f
    end

    context 'validates' do
      before do
        klass_with_validation.create_table
      end

      it 'does not create when invalid' do
        obj1 = nil
        expect {
          described_class.execute do |txn|
            obj1 = txn.create(klass_with_validation, name: 'one')
          end
        }.not_to change { klass_with_validation.count }
        expect(obj1).to eql false
      end

      it 'rolls back when invalid' do
        obj1 = nil
        obj2 = nil
        described_class.execute do |txn|
          obj1 = txn.create(klass_with_validation, name: 'one')
          obj2 = txn.create(klass_with_validation, name: 'twotwo')
        end
        expect(obj1).to eql false
        expect(obj2).to_not be_nil
        expect(klass_with_validation).to exist(obj2.id)
      end

      it 'succeeds when valid' do
        obj1 = nil
        described_class.execute do |txn|
          obj1 = txn.create(klass_with_validation, name: 'oneone')
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'raises DocumentNotValid when not valid' do
        expect {
          expect {
            described_class.execute do |txn|
              txn.create! klass_with_validation, name: 'one'
            end
          }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        }.not_to change { klass_with_validation.count }
      end

      it 'rolls back and raises DocumentNotValid when not valid' do
        obj1 = nil
        obj2 = nil
        expect {
          expect {
            described_class.execute do |txn|
              obj2 = txn.create! klass_with_validation, name: 'twotwo'
              obj1 = txn.create! klass_with_validation, name: 'one'
            end
          }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        }.not_to change { klass_with_validation.count }
        expect(obj1).to be_nil
        expect(obj2).to_not be_nil
        # expect(obj2).to be_persisted # FIXME
      end

      it 'does not raise exception when valid' do
        obj1 = nil
        described_class.execute do |txn|
          obj1 = txn.create! klass_with_validation, name: 'oneone'
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
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
end
