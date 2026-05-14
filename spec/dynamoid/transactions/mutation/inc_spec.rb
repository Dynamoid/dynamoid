# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Transactions::Mutation, '.inc' do
  let(:document_class) do
    new_class do
      field :links_count, :integer
      field :mentions_count, :integer
    end
  end

  let(:klass_with_composite_key) do
    new_class do
      range :name
      field :links_count, :integer
    end
  end

  it 'adds specified value' do
    obj = document_class.create!(links_count: 2)

    described_class.execute do |t|
      t.inc(document_class, obj.id, links_count: 5)
    end

    expect(document_class.find(obj.id).links_count).to eq(7)
  end

  it 'accepts negative value' do
    obj = document_class.create!(links_count: 10)

    described_class.execute do |t|
      t.inc(document_class, obj.id, links_count: -2)
    end

    expect(document_class.find(obj.id).links_count).to eq(8)
  end

  it 'treats nil value as zero' do
    obj = document_class.create!(links_count: nil)

    described_class.execute do |t|
      t.inc(document_class, obj.id, links_count: 5)
    end

    expect(document_class.find(obj.id).links_count).to eq(5)
  end

  it 'supports passing several attributes at once' do
    obj = document_class.create!(links_count: 2, mentions_count: 31)

    described_class.execute do |t|
      t.inc(document_class, obj.id, links_count: 5, mentions_count: 9)
    end

    expect(document_class.find(obj.id).links_count).to eql(7)
    expect(document_class.find(obj.id).mentions_count).to eql(40)
  end

  it 'accepts sort key if it is declared' do
    class_with_sort_key = new_class do
      range :author_name
      field :links_count, :integer
    end

    obj = class_with_sort_key.create!(author_name: 'Mike', links_count: 2)

    described_class.execute do |t|
      t.inc(class_with_sort_key, obj.id, 'Mike', links_count: 5)
    end

    expect(obj.reload.links_count).to eql(7)
  end

  it 'uses dumped value of partition key to update item' do
    klass = new_class(partition_key: { name: :published_on, type: :date }) do
      field :links_count, :integer
    end

    obj = klass.create!(published_on: '2018-10-07'.to_date, links_count: 2)

    described_class.execute do |t|
      t.inc(klass, '2018-10-07'.to_date, links_count: 5)
    end

    expect(obj.reload.links_count).to eql(7)
  end

  it 'uses dumped value of sort key to update item' do
    class_with_sort_key = new_class do
      range :published_on, :date
      field :links_count, :integer
    end

    obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)

    described_class.execute do |t|
      t.inc(class_with_sort_key, obj.id, '2018-10-07'.to_date, links_count: 5)
    end

    expect(obj.reload.links_count).to eql(7)
  end

  it 'returns nil' do
    obj = document_class.create!(links_count: 2)

    result = true
    described_class.execute do |t|
      result = t.inc(document_class, obj.id, links_count: 5)
    end

    expect(result).to eql(nil)
  end

  it 'updates `updated_at` attribute when touch: true option passed' do
    obj = document_class.create!(links_count: 2, updated_at: Time.now - 1.day)

    described_class.execute do |t|
      t.inc(document_class, obj.id, links_count: 5, touch: true)
    end

    expect(document_class.find(obj.id).updated_at).to be > (Time.now - 1.minute)
  end

  it 'updates `updated_at` and the specified attributes when touch: name option passed' do
    klass = new_class do
      field :links_count, :integer
      field :viewed_at, :datetime
    end

    obj = klass.create!(viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

    described_class.execute do |t|
      t.inc(klass, obj.id, links_count: 5, touch: :viewed_at)
    end

    item = klass.find(obj.id)
    expect(item.viewed_at).to be > (Time.now - 1.minute)
    expect(item.updated_at).to be > (Time.now - 1.minute)
  end

  it 'updates `updated_at` and the specified attributes when touch: [<name>*] option passed' do
    klass = new_class do
      field :links_count, :integer
      field :viewed_at, :datetime
      field :tagged_at, :datetime
    end

    obj = klass.create!(
      viewed_at: Time.now - 1.day,
      tagged_at: Time.now - 3.days,
      updated_at: Time.now - 2.days
    )

    described_class.execute do |t|
      t.inc(klass, obj.id, links_count: 5, touch: %i[viewed_at tagged_at])
    end

    item = klass.find(obj.id)
    expect(item.updated_at).to be > (Time.now - 1.minute)
    expect(item.viewed_at).to be > (Time.now - 1.minute)
    expect(item.tagged_at).to be > (Time.now - 1.minute)
  end

  describe 'timestamps' do
    it 'does not change updated_at', config: { timestamps: true } do
      obj = document_class.create!
      expect(obj.updated_at).to be_present

      described_class.execute do |t|
        t.inc(document_class, obj.id, links_count: 5)
      end

      expect(document_class.find(obj.id).updated_at).to eq(obj.updated_at)
    end
  end

  describe 'type casting' do
    it 'uses casted value of sort key to call UpdateItem' do
      klass = new_class(partition_key: { name: :id, type: :integer }) do
        range :count, :integer
        field :links_count, :integer
      end

      obj = klass.create!(id: 1, count: 101, links_count: 2)

      described_class.execute do |t|
        t.inc(klass, '1', '101', links_count: 5)
      end

      expect(obj.reload.links_count).to eql(7)
    end

    it 'type casts attributes' do
      obj = document_class.create!(links_count: 2)

      described_class.execute do |t|
        t.inc(document_class, obj.id, links_count: '5.12345')
      end

      expect(document_class.find(obj.id).links_count).to eq(7)
    end
  end

  describe 'primary key validation' do
    context 'simple primary key' do
      it 'requires partition key to be specified' do
        expect {
          described_class.execute do |t|
            t.inc document_class, nil, links_count: 1
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      it 'requires partition key to be specified' do
        expect {
          described_class.execute do |t|
            t.inc klass_with_composite_key, nil, 'Alex', links_count: 1
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        id_new = SecureRandom.uuid

        expect {
          described_class.execute do |t|
            t.inc klass_with_composite_key, id_new, nil, links_count: 1
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  it "raises UnknownAttribute when an attribute name isn't declared as a field" do
    obj = document_class.create!

    expect {
      described_class.execute do |t|
        t.inc(document_class, obj.id, unknown: 1)
      end
    }.to raise_error(Dynamoid::Errors::UnknownAttribute)
  end

  # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
  it 'allows reserved keywords as attribute names' do
    klass = new_class do
      field :counter, :integer
    end
    obj = klass.create!(counter: 10)

    described_class.execute do |t|
      t.inc(klass, obj.id, counter: 1)
    end

    expect(obj.reload.counter).to eq(11)
  end

  # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
  it 'allows reserved words as partition key and sort key' do
    klass = new_class(partition_key: { name: :name, type: :string }) do
      range :status, :string
      field :age, :integer
    end
    obj = klass.create!(name: 'Alex', status: 'active', age: 3)

    described_class.execute do |t|
      t.inc klass, obj.name, obj.status, age: 4
    end

    expect(obj.reload.age).to eql(7)
  end

  context 'when a model was concurrently deleted' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    let(:klass_with_composite_key) do
      new_class do
        range :name
        field :age, :integer
      end
    end

    let(:klass_with_composite_key_and_custom_type) do
      new_class do
        range :tags, :serialized
        field :age, :integer
      end
    end

    it 'does not persist changes when simple primary key' do
      obj = klass.create!(age: 21)
      klass.find(obj.id).delete

      expect {
        described_class.execute do |t|
          t.inc klass, obj.id, age: 1
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end

    it 'does not persist changes when composite primary key' do
      obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
      klass_with_composite_key.find(obj.id, range_key: obj.name).delete

      expect {
        described_class.execute do |t|
          t.inc klass_with_composite_key, obj.id, obj.name, age: 1
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end

    it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
      obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], age: 21)
      klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

      expect {
        described_class.execute do |t|
          t.inc klass_with_composite_key_and_custom_type, obj.id, obj.tags, age: 1
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)
    end
  end

  # dynamodb-local doesn't support ARN for TableName request
  # attribute and the following error is returned:
  #   Aws::DynamoDB::Errors::ResourceNotFoundException:
  #    Cannot do operations on a non-existent table
  context 'when table arn is specified' do
    it 'uses given table ARN in requests instead of a table name' do
      skip 'cannot test with dynamodb-local'
    end
  end
end
