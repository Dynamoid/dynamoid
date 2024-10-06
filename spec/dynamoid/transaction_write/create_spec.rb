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

      it 'with attribute in constructor' do
        obj1 = klass.new(name: 'one')
        expect(obj1.persisted?).to eql(false)
        described_class.execute do |txn|
          txn.create! obj1
        end
        expect(obj1.persisted?).to eql(true)
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('one')
      end

      it 'with attribute in transaction' do
        obj2 = klass.new
        described_class.execute do |txn|
          txn.create! obj2, name: 'two'
        end
        obj2_found = klass.find(obj2.id)
        expect(obj2_found).to eql(obj2)
        expect(obj2_found.name).to eql('two')
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

      it 'with attribute in constructor' do
        obj1 = klass_with_composite_key.new(name: 'one', age: 1)
        described_class.execute do |txn|
          txn.create! obj1
        end
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('one')
      end

      it 'with attribute in transaction' do
        obj2 = klass_with_composite_key.new
        described_class.execute do |txn|
          txn.create! obj2, name: 'two', age: 2
        end
        obj2_found = klass_with_composite_key.find(obj2.id, range_key: 2)
        expect(obj2_found).to eql(obj2)
        expect(obj2_found.name).to eql('two')
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
      obj1 = klass.new(name: 'one')
      expect(obj1.created_at).to be_nil
      expect(obj1.updated_at).to be_nil
      described_class.execute do |txn|
        txn.create! obj1
      end
      obj1_found = klass.find(obj1.id)
      expect(obj1_found.created_at.to_f).to be_within(1.seconds).of Time.now.to_f
      expect(obj1_found.updated_at.to_f).to be_within(1.seconds).of Time.now.to_f
    end

    context 'validates' do
      before do
        klass_with_validation.create_table
      end

      it 'does not create when invalid' do
        obj1 = klass_with_validation.new(name: 'one')
        described_class.execute do |txn|
          expect(txn.create(obj1)).to eql(false)
        end
        expect(obj1.id).to be_nil
      end

      it 'rolls back when invalid' do
        obj1 = klass_with_validation.new(name: 'one')
        obj2 = klass_with_validation.new(name: 'twotwo')
        described_class.execute do |txn|
          expect(txn.create(obj1)).to eql(false)
          expect(txn.create(obj2)).to be_present
        end
        expect(obj1.id).to be_nil
        expect(klass_with_validation).to exist(obj2.id)
      end

      it 'succeeds when valid' do
        obj1 = klass_with_validation.new(name: 'oneone')
        described_class.execute do |txn|
          expect(txn.create(obj1)).to be_present
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'raises DocumentNotValid when not valid' do
        obj1 = klass_with_validation.new(name: 'one')
        expect {
          described_class.execute do |txn|
            txn.create! obj1
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        expect(obj1.id).to be_nil # hash key should NOT be auto-generated if validation fails
      end

      it 'rolls back and raises DocumentNotValid when not valid' do
        obj1 = klass_with_validation.new(name: 'one')
        obj2 = klass_with_validation.new(name: 'twotwo')
        expect {
          described_class.execute do |txn|
            txn.create! obj2
            txn.create! obj1
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        expect(obj1.id).to be_nil
        expect(obj2.id).to be_present
        expect(klass_with_validation).not_to exist(obj2.id)
      end

      it 'does not raise exception when valid' do
        obj1 = klass_with_validation.new(name: 'oneone')
        described_class.execute do |txn|
          txn.create!(obj1)
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'does not raise exception when skipping validation' do
        obj1 = klass_with_validation.new(name: 'one')
        described_class.execute do |txn|
          # this use is infrequent, normal entry is from save!(obj, options)
          txn.create!(obj1, {}, skip_validation: true)
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('one')
      end
    end

    context 'when an issue detected on the DynamoDB side' do
      it 'rolls back the changes when id is not unique' do
        existing = klass.create!(name: 'one')

        obj1 = klass.new(name: 'one', id: existing.id)
        obj2 = klass.new(name: 'two')

        expect {
          described_class.execute do |txn|
            txn.create! obj1
            txn.create! obj2
          end
        }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

        expect(klass.count).to eql 1
        expect(klass.all.to_a).to eql [existing]

        expect(obj1.persisted?).to eql false
        expect(obj2.persisted?).to eql false
      end
    end

    it 'uses callbacks' do
      klass_with_callbacks.create_table
      expect {
        described_class.execute do |txn|
          txn.create! klass_with_callbacks.new(name: 'two')
        end
      }.to output('validating validated saving creating created saved ').to_stdout
    end

    it 'uses around callbacks' do
      klass_with_around_callbacks.create_table
      expect {
        described_class.execute do |txn|
          txn.create! klass_with_around_callbacks.new(name: 'two')
        end
      }.to output('saving creating created saved ').to_stdout
    end
  end
end
