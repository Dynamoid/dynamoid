# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.inc' do
    let(:document_class) do
      new_class do
        field :links_count, :integer
        field :mentions_count, :integer
      end
    end

    it 'adds specified value' do
      obj = document_class.create!(links_count: 2)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
    end

    it 'accepts negative value' do
      obj = document_class.create!(links_count: 10)

      expect {
        document_class.inc(obj.id, links_count: -2)
      }.to change { document_class.find(obj.id).links_count }.from(10).to(8)
    end

    it 'traits nil value as zero' do
      obj = document_class.create!(links_count: nil)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(nil).to(5)
    end

    it 'supports passing several attributes at once' do
      obj = document_class.create!(links_count: 2, mentions_count: 31)
      document_class.inc(obj.id, links_count: 5, mentions_count: 9)

      expect(document_class.find(obj.id).links_count).to eql(7)
      expect(document_class.find(obj.id).mentions_count).to eql(40)
    end

    it 'accepts sort key if it is declared' do
      class_with_sort_key = new_class do
        range :author_name
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(author_name: 'Mike', links_count: 2)
      class_with_sort_key.inc(obj.id, 'Mike', links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of partition key to update item' do
      klass = new_class(partition_key: { name: :published_on, type: :date }) do
        field :links_count, :integer
      end

      obj = klass.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      klass.inc('2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of sort key to update item' do
      class_with_sort_key = new_class do
        range :published_on, :date
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      class_with_sort_key.inc(obj.id, '2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'returns self' do
      obj = document_class.create!(links_count: 2)

      expect(document_class.inc(obj.id, links_count: 5)).to eq(document_class)
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create!(links_count: 2, updated_at: Time.now - 1.day)

      expect { document_class.inc(obj.id, links_count: 5) }.not_to change { document_class.find(obj.id).updated_at }
      expect { document_class.inc(obj.id, links_count: 5, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: name option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
      end

      obj = klass.create!(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

      expect do
        expect do
          klass.inc(obj.id, links_count: 5, touch: :viewed_at)
        end.to change { klass.find(obj.id).updated_at }
      end.to change { klass.find(obj.id).viewed_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: [<name>*] option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
        field :tagged_at, :datetime
      end

      obj = klass.create!(
        age: 21,
        viewed_at: Time.now - 1.day,
        tagged_at: Time.now - 3.days,
        updated_at: Time.now - 2.days
      )

      expect do
        expect do
          expect do
            klass.inc(obj.id, links_count: 5, touch: %i[viewed_at tagged_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end.to change { klass.find(obj.id).tagged_at }
    end

    describe 'timestamps' do
      it 'does not change updated_at', config: { timestamps: true } do
        obj = document_class.create!
        expect(obj.updated_at).to be_present

        expect {
          document_class.inc(obj.id, links_count: 5)
        }.not_to change { document_class.find(obj.id).updated_at }
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        class_with_sort_key = new_class do
          range :published_on, :date
          field :links_count, :integer
        end

        obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
        class_with_sort_key.inc(obj.id, '2018-10-07', links_count: 5)

        expect(obj.reload.links_count).to eql(7)
      end

      it 'type casts attributes' do
        obj = document_class.create!(links_count: 2)

        expect {
          document_class.inc(obj.id, links_count: '5.12345')
        }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
      end
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

        klass.inc obj.id, age: 1
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        klass_with_composite_key.inc obj.id, obj.name, age: 1
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], age: 21)
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        klass_with_composite_key_and_custom_type.inc obj.id, obj.tags, age: 1
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end

    context 'when table arn is specified', remove_constants: [:Payment] do
      it 'uses given table ARN in requests instead of a table name', config: { create_table_on_save: false } do
        # Create table manually because CreateTable doesn't accept ARN as a
        # table name. Add namespace to have this table removed automativally.
        table_name = :"#{Dynamoid::Config.namespace}_purchases"
        Dynamoid.adapter.create_table(table_name, :id)

        table = Dynamoid.adapter.describe_table(table_name)
        expect(table.arn).to be_present

        Payment = Class.new do # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
          include Dynamoid::Document

          table arn: table.arn
          field :amount, :integer
        end

        payment = Payment.create!

        expect {
          Payment.inc(payment.id, amount: 10)
        }.to send_request_matching(:UpdateItem, { TableName: table.arn })
      end
    end
  end
end
