# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.save' do # 'save' is an update or create
  include_context 'transaction_write'

  # a 'save' does an update or create depending on if the record is new or not
  context 'saves' do
    context 'simple primary key' do
      before do
        klass.create_table
      end

      it 'with an update' do
        obj1 = klass.create!(name: 'one')
        described_class.execute do |txn|
          obj1.name = 'oneone'
          txn.save! obj1
        end
        obj1_found = klass.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'with a create' do
        obj2 = klass.new(name: 'two')
        described_class.execute do |txn|
          txn.save! obj2
        end
        obj2_found = klass.find(obj2.id)
        expect(obj2_found).to eql(obj2)
        expect(obj2_found.name).to eql('two')
      end
    end

    context 'composite key' do
      before do
        klass_with_composite_key.create_table
      end

      it 'with an update' do
        obj1 = klass_with_composite_key.create!(name: 'one', age: 1)
        described_class.execute do |txn|
          obj1.name = 'oneone'
          txn.save! obj1
        end
        obj1_found = klass_with_composite_key.find(obj1.id, range_key: 1)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'with a create' do
        obj2 = klass_with_composite_key.new(name: 'two', age: 2)
        described_class.execute do |txn|
          txn.save! obj2
        end
        obj2_found = klass_with_composite_key.find(obj2.id, range_key: 2)
        expect(obj2_found).to eql(obj2)
        expect(obj2_found.name).to eql('two')
      end
    end

    context 'validates' do
      before do
        klass_with_validation.create_table
      end

      it 'does not save when invalid' do
        obj1 = klass_with_validation.new(name: 'one')
        described_class.execute do |txn|
          expect(txn.save(obj1)).to eql(false)
        end
        expect(obj1.id).to be_nil
      end

      it 'allows partial save when a record in the transaction is invalid' do
        obj1 = klass_with_validation.new(name: 'one')
        obj2 = klass_with_validation.create!(name: 'twolong')
        obj2.name = 'twotwo'
        described_class.execute do |txn|
          expect(txn.save(obj2)).to be_truthy
          expect(txn.save(obj1)).to eql(false)
        end
        expect(obj1.id).to be_nil
        obj2_found = klass_with_validation.find(obj2.id)
        expect(obj2_found.name).to eql('twotwo')
      end

      it 'saves when valid' do
        obj1 = klass_with_validation.new(name: 'oneone')
        described_class.execute do |txn|
          expect(txn.save(obj1)).to be_present
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'raises DocumentNotValid when not valid' do
        obj1 = klass_with_validation.new(name: 'one')
        expect {
          described_class.execute do |txn|
            txn.save! obj1
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        expect(obj1.id).to be_nil
      end

      it 'rolls back and raises DocumentNotValid when not valid' do
        obj1 = klass_with_validation.new(name: 'one')
        obj2 = klass_with_validation.create!(name: 'twolong')
        obj2.name = 'twotwo'
        expect {
          described_class.execute do |txn|
            txn.save! obj2
            txn.save! obj1
          end
        }.to raise_error(Dynamoid::Errors::DocumentNotValid)
        expect(obj1.id).to be_nil
        obj2_found = klass_with_validation.find(obj2.id)
        expect(obj2_found.name).to eql('twolong')
      end

      it 'does not raise exception when valid' do
        obj1 = klass_with_validation.new(name: 'oneone')
        described_class.execute do |txn|
          txn.save!(obj1)
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('oneone')
      end

      it 'does not raise exception when skipping validation' do
        obj1 = klass_with_validation.new(name: 'one')
        described_class.execute do |txn|
          txn.save!(obj1, skip_validation: true)
        end

        obj1_found = klass_with_validation.find(obj1.id)
        expect(obj1_found).to eql(obj1)
        expect(obj1_found.name).to eql('one')
      end
    end

    context 'callabacks' do
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

      it 'cak skip callbacks' do
        klass_with_callbacks.create_table
        expect {
          described_class.execute do |txn|
            txn.save! klass_with_callbacks.new(name: 'two'), skip_callbacks: true
          end
        }.to output('validating validated ').to_stdout # ActiveModel runs validation callbacks when we validate
      end

      it 'cak skip callbacks and validation' do
        klass_with_callbacks.create_table
        expect {
          described_class.execute do |txn|
            txn.save! klass_with_callbacks.new(name: 'two'), skip_callbacks: true, skip_validation: true
          end
        }.not_to output.to_stdout
      end
    end
  end
end
