# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dynamoid::Transactions::Mutation, '#increment!' do
  let(:klass) do
    new_class do
      field :age, :integer
    end
  end

  let(:klass_with_composite_key) do
    new_class do
      range :name, :serialized
      field :age, :integer
    end
  end

  let(:klass_with_composite_key_and_custom_type) do
    new_class do
      range :tags, :serialized
      field :age, :integer
    end
  end

  it 'increments an attribute by 1 by default' do
    obj = klass.create!(age: 21)

    expect {
      described_class.execute { |t| t.increment!(obj, :age) }
    }.to change { obj.age }.from(21).to(22)
  end

  it 'treats nil as zero' do
    obj = klass.create!(age: nil)

    expect {
      described_class.execute { |t| t.increment!(obj, :age) }
    }.to change { obj.age }.from(nil).to(1)
  end

  it 'increments by a specified amount' do
    obj = klass.create!(age: 21)

    expect {
      described_class.execute { |t| t.increment!(obj, :age, 10) }
    }.to change { obj.age }.from(21).to(31)
  end

  it 'persists the updated attribute' do
    obj = klass.create!(age: 21)
    described_class.execute { |t| t.increment!(obj, :age, 10) }
    expect(obj.reload.age).to eq 31
  end

  it 'does not persist other dirty attributes' do
    klass = new_class do
      field :age, :integer
      field :title
    end

    obj = klass.create!(age: 21, title: 'title')
    obj.title = 'new title'
    described_class.execute { |t| t.increment!(obj, :age) }

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.title).to eq 'title'
  end

  it 'leaves other dirty attributes unchanged in memory' do
    klass = new_class do
      field :age, :integer
      field :title
    end

    obj = klass.create!(age: 21, title: 'title')
    obj.title = 'new title'
    described_class.execute { |t| t.increment!(obj, :age) }

    expect(obj.title).to eq 'new title'
    expect(obj.title_changed?).to eq true
  end

  it 'returns self' do
    obj = klass.create!(age: 21)
    result = nil
    described_class.execute { |t| result = t.increment!(obj, :age, 10) }
    expect(result).to eq obj
  end

  it 'clears the dirty state of the incremented attribute' do
    obj = klass.create!(age: 21)
    described_class.execute { |t| t.increment!(obj, :age, 10) }

    expect(obj.age_changed?).to eq false
  end

  it 'skips validations' do
    class_with_validation = new_class do
      field :age, :integer
      validates :age, numericality: { less_than: 16 }
    end

    obj = class_with_validation.create!(age: 10)
    described_class.execute { |t| t.increment!(obj, :age, 7) }
    expect(obj.valid?).to eq false
    expect(obj.reload.age).to eq 17
  end

  it 'skips save callbacks' do
    ScratchPad.record []
    klass = new_class do
      field :age, :integer
      before_save { ScratchPad << 'run before_save' }
    end

    obj = klass.create!(age: 21)
    ScratchPad.clear
    described_class.execute { |t| t.increment!(obj, :age, 10) }
    expect(ScratchPad.recorded).to be_empty
  end

  it "raises UnknownAttribute when an attribute name isn't declared as a field" do
    obj = klass.create!
    expect {
      described_class.execute { |t| t.increment!(obj, :unknown) }
    }.to raise_error(Dynamoid::Errors::UnknownAttribute)
  end

  it 'allows reserved words as attribute names' do
    klass = new_class do
      field :counter, :integer
    end
    obj = klass.create!(counter: 10)

    described_class.execute { |t| t.increment!(obj, :counter, 1) }

    expect(obj.reload.counter).to eq(11)
  end

  it 'supports models with a sort key' do
    klass_with_sort_key = new_class do
      range :name
      field :age, :integer
    end

    obj = klass_with_sort_key.create!(name: 'Alex', age: 21)
    described_class.execute { |t| t.increment!(obj, :age, 10) }
    expect(obj.reload.age).to eq 31
  end

  context 'when :touch option passed' do
    it 'updates updated_at when touch: true' do
      obj = klass.create!(age: 21, updated_at: Time.now - 1.day)

      expect {
        described_class.execute { |t| t.increment!(obj, :age) }
      }.not_to change { obj.reload.updated_at }

      expect {
        described_class.execute { |t| t.increment!(obj, :age, touch: true) }
      }.to change { obj.reload.updated_at }
    end

    it 'updates specified attributes alongside updated_at' do
      klass = new_class do
        field :age, :integer
        field :viewed_at, :datetime
      end

      obj = klass.create!(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

      expect do
        expect do
          described_class.execute { |t| t.increment!(obj, :age, touch: [:viewed_at]) }
        end.to change { obj.reload.updated_at }
      end.to change { obj.reload.viewed_at }
    end

    it 'triggers after_touch callbacks' do
      klass_with_callback = new_class do
        field :age, :integer
        after_touch { ScratchPad << 'run after_touch' }
      end

      obj = klass_with_callback.create!
      ScratchPad.clear

      described_class.execute { |t| t.increment!(obj, :age, touch: true) }
      expect(ScratchPad.recorded).to eq(['run after_touch'])
    end
  end

  describe 'callbacks' do
    it 'runs after_commit callbacks' do
      klass_with_callback = new_class do
        field :age, :integer
        after_commit { ScratchPad << "after_commit #{id}" }
      end
      klass_with_callback.create_table
      ScratchPad.record []
      obj = klass_with_callback.create!(id: '1')
      ScratchPad.record []

      described_class.execute do |t|
        t.increment!(obj, :age)
      end

      expect(ScratchPad.recorded).to contain_exactly('after_commit 1')
    end

    it 'runs after_rollback callbacks when exception is raised and aborts a transaction' do
      klass_with_callback = new_class do
        field :age, :integer
        after_rollback { ScratchPad << "after_rollback #{id}" }
      end
      klass_with_callback.create_table
      ScratchPad.record []
      obj = klass_with_callback.create!(id: '1')
      ScratchPad.record []

      begin
        described_class.execute do |t|
          t.increment!(obj, :age)
          raise 'error'
        end
      rescue StandardError => e
        expect(e.message).to eq('error')
      end

      expect(ScratchPad.recorded).to contain_exactly('after_rollback 1')
    end

    it 'runs after_rollback callbacks when a transaction is rolled back' do
      klass_with_callback = new_class do
        field :age, :integer
        after_rollback { ScratchPad << "after_rollback #{id}" }
      end
      klass_with_callback.create_table

      klass.create(id: 'unique_id')

      ScratchPad.record []
      obj = klass_with_callback.create!(id: '1')
      ScratchPad.record []

      begin
        described_class.execute do |t|
          t.increment!(obj, :age)
          t.create klass, id: 'unique_id' # triggers rollback
        end
      rescue Aws::DynamoDB::Errors::TransactionCanceledException
        # ignore
      end

      expect(ScratchPad.recorded).to contain_exactly('after_rollback 1')
    end
  end

  describe 'primary key validation' do
    context 'simple primary key' do
      it 'requires partition key to be specified' do
        obj = klass.new
        expect {
          described_class.execute do |t|
            t.increment! obj, :age
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      it 'requires partition key to be specified' do
        obj = klass_with_composite_key.new(name: 'Alex')
        expect {
          described_class.execute do |t|
            t.increment! obj, :age
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        obj = klass_with_composite_key.new(id: '1')
        expect {
          described_class.execute do |t|
            t.increment! obj, :age
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  context 'when a model was concurrently deleted' do
    it 'rolls transaction back for a simple primary key' do
      obj = klass.create!(age: 21)
      klass.find(obj.id).delete

      expect {
        described_class.execute { |t| t.increment!(obj, :age) }
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end

    it 'rolls transaction back for a composite primary key' do
      obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
      klass_with_composite_key.find(obj.id, range_key: obj.name).delete

      expect {
        described_class.execute { |t| t.increment!(obj, :age) }
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end

    it 'rolls transaction back when sort key type is not supported natively' do
      obj = klass_with_composite_key_and_custom_type.create!(name: 'Alex', tags: %w[a b], age: 21)
      klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

      expect {
        described_class.execute { |t| t.increment!(obj, :age) }
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end
  end

  context 'when table arn is specified' do
    it 'uses the table ARN' do
      skip 'cannot test with dynamodb-local'
    end
  end
end
