# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.destroy' do
  include_context 'transaction_write'

  it 'deletes a model and accepts a model itself' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.destroy obj
      end
    }.to change { klass.count }.by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')

    result = nil
    described_class.execute do |txn|
      result = txn.destroy obj
    end

    expect(result).to be_a(klass)
    expect(result).to equal(obj)
    # expect(result).to be_destroyed # FIXME
  end

  describe 'primary key schemas' do
    context 'simple primary key' do
      it 'deletes a model' do
        obj = klass.create!(name: 'one')

        expect {
          described_class.execute do |txn|
            txn.destroy obj
          end
        }.to change { klass.count }.by(-1)
      end
    end

    context 'composite key' do
      it 'deletes a model' do
        obj = klass_with_composite_key.create!(name: 'one', age: 1)

        expect {
          described_class.execute do |txn|
            txn.destroy obj
          end
        }.to change { klass_with_composite_key.count }.by(-1)
      end
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    # FIXME
    # it 'does not roll back the changes when a model to destroy does not exist' do
    #   obj1 = klass.create!(name: 'one', id: '1')
    #   obj1.id = 'not-existing'
    #   obj2 = klass.new(name: 'two', id: '2')

    #   expect {
    #     described_class.execute do |txn|
    #       txn.destroy obj1
    #       txn.save obj2
    #     end
    #   }.to change { klass.count }.by(1)

    #   expect(obj1.destroyed?).to eql nil
    #   expect(obj2.persisted?).to eql true
    #   expect(klass.all.to_a.map(&:id)).to contain_exactly('1', obj2.id)
    # end
  end

  describe 'callbacks' do
    it 'uses callbacks' do
      obj = klass_with_callbacks.create!

      expect {
        described_class.execute do |txn|
          txn.destroy obj
        end
      }.to output('destroying destroyed ').to_stdout
    end

    it 'uses around callbacks' do
      obj = klass_with_around_callbacks.create!

      expect {
        described_class.execute do |txn|
          txn.destroy obj
        end
      }.to output('destroying destroyed ').to_stdout
    end

    it 'aborts destroying and returns false if a before_destroy callback throws :abort' do
      klass = new_class do
        before_destroy { throw :abort }
      end
      obj = klass.create!

      result = nil
      expect {
        described_class.execute do |txn|
          result = txn.destroy obj
        end
      }.not_to change { klass.count }

      # expect(result).to eql false # FIXME
      expect(obj.destroyed?).to eql nil
    end

    it 'does not roll back the whole transaction when a destroying of some model aborted by a before_destroy callback' do
      klass = new_class do
        before_destroy { throw :abort }
      end

      obj_to_destroy = klass.create!
      obj_to_save = klass.new

      expect {
        described_class.execute do |txn|
          txn.save obj_to_save
          txn.destroy obj_to_destroy
        end
      }.to change { klass.count }.by(1)

      expect(obj_to_save.persisted?).to eql true
      expect(obj_to_destroy.destroyed?).to eql nil
      expect(klass.exists?(obj_to_destroy.id)).to eql true
      expect(klass.exists?(obj_to_save.id)).to eql true
    end
  end
end

describe Dynamoid::TransactionWrite, '.destroy!' do
  include_context 'transaction_write'

  it 'deletes a model and accepts a model itself' do
    obj = klass.create!(name: 'one')

    expect {
      described_class.execute do |txn|
        txn.destroy! obj
      end
    }.to change { klass.count }.by(-1)

    expect(klass.exists?(obj.id)).to eql false
  end

  it 'returns a model' do
    obj = klass.create!(name: 'one')

    result = nil
    described_class.execute do |txn|
      result = txn.destroy! obj
    end

    expect(result).to be_a(klass)
    expect(result).to equal(obj)
    # expect(result).to be_destroyed # FIXME
  end

  describe 'callbacks' do
    # FIXME
    # it 'aborts destroying and raises RecordNotDestroyed if a before_destroy callback throws :abort' do
    #   klass = new_class do
    #     before_destroy { throw :abort }
    #   end
    #   obj = klass.create!

    #   expect {
    #     expect {
    #       described_class.execute do |txn|
    #         txn.destroy! obj
    #       end
    #     }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
    #   }.not_to change { klass.count }

    #   expect(obj.destroyed?).to eql nil
    # end

    # FIXME
    # it 'rolls back the whole transaction when a destroying of some model aborted by a before_destroy callback' do
    #   klass = new_class do
    #     before_destroy { throw :abort }
    #   end

    #   obj_to_destroy = klass.create!
    #   obj_to_save = klass.new

    #   expect {
    #     expect {
    #     described_class.execute do |txn|
    #       txn.save obj_to_save
    #       txn.destroy! obj_to_destroy
    #     end
    #     }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
    #   }.not_to change { klass.count }

    #   expect(obj_to_save.persisted?).to eql false
    #   expect(obj_to_destroy.destroyed?).to eql nil
    #   expect(klass.exists?(obj_to_destroy.id)).to eql true
    #   expect(klass.exists?(obj_to_save.id)).to eql false
    # end
  end
end
