# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.upsert' do
    let(:klass) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    let(:klass_with_composite_key) do
      new_class do
        range :age, :integer
        field :name
      end
    end

    it 'changes field value' do
      obj = klass.create(title: 'Old title')
      expect do
        klass.upsert(obj.id, title: 'New title')
      end.to change { klass.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = klass.create(title: 'New Document')
      expect do
        klass.upsert(obj.id, title: nil)
      end.to change { klass.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = klass.create(title: 'Old title')
      result = klass.upsert(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'conditions specified' do
      describe 'if condition' do
        it 'updates when model matches conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          expect {
            klass.upsert(obj.id, { title: 'New title' }, if: { version: 1 })
          }.to change { klass.find(obj.id).title }.to('New title')
        end

        it 'does not update when model does not match conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          expect {
            result = klass.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
          }.not_to change { klass.find(obj.id).title }
        end

        it 'returns nil when model does not match conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          result = klass.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
          expect(result).to eq nil
        end
      end

      describe 'unless_exists condition' do
        it 'updates when item does not have specified attribute' do
          # not specifying field value means (by default) the attribute will be
          # skipped and not persisted in DynamoDB
          obj = klass.create(title: 'Old title')
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :created_at, :updated_at)

          expect {
            klass.upsert(obj.id, { title: 'New title' }, { unless_exists: [:version] })
          }.to change { klass.find(obj.id).title }.to('New title')
        end

        it 'does not update when model has specified attribute' do
          obj = klass.create(title: 'Old title', version: 1)
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

          expect {
            result = klass.upsert(obj.id, { title: 'New title' }, { unless_exists: [:version] })
          }.not_to change { klass.find(obj.id).title }
        end

        context 'when multiple attribute names' do
          it 'updates when item does not have all the specified attributes' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = klass.create(title: 'Old title')
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :created_at, :updated_at)

            expect {
              klass.upsert(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.to change { klass.find(obj.id).title }.to('New title')
          end

          it 'does not update when model has all the specified attributes' do
            obj = klass.create(title: 'Old title', version: 1, published_on: '2018-02-23'.to_date)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :published_on, :created_at, :updated_at)

            expect {
              result = klass.upsert(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.not_to change { klass.find(obj.id).title }
          end

          it 'does not update when model has at least one specified attribute' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = klass.create(title: 'Old title', version: 1)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

            expect {
              result = klass.upsert(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.not_to change { klass.find(obj.id).title }
          end
        end
      end
    end

    it 'creates new document if it does not exist yet' do
      klass.create_table

      expect do
        klass.upsert('not-existed-id', title: 'Title')
      end.to change(klass, :count)

      obj = klass.find('not-existed-id')
      expect(obj.title).to eq 'Title'
    end

    it 'accepts range key if it is declared' do
      klass_with_range = new_class do
        field :title
        range :category
      end

      obj = klass_with_range.create(category: 'New')

      expect do
        klass_with_range.upsert(obj.id, 'New', title: '[Updated]')
      end.to change {
        klass_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    # TODO: implement the test later
    # it 'raises ...Error when range key is missing'

    # TODO: add this case for save/save! and update_attributes/other update operations
    # as well as you cannot update id (partition key)
    it 'does not allow to update a range key value' do
      klass_with_range = new_class do
        field :title
        range :category
      end

      obj = klass_with_range.create!(category: 'New')

      expect {
        klass_with_range.upsert(obj.id, 'New', category: '[Updated]')
      }.to raise_error(Aws::DynamoDB::Errors::ValidationException)
    end

    it 'uses dumped value of partition key to update item' do
      klass = new_class(partition_key: { name: :published_on, type: :date }) do
        field :title
      end

      obj = klass.create!(published_on: '2018-10-07'.to_date, title: 'Old')
      klass.upsert('2018-10-07'.to_date, title: 'New')

      expect(obj.reload.title).to eq 'New'
    end

    it 'uses dumped value of sort key to update item' do
      klass_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = klass_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      klass_with_range.upsert(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = klass.create
      klass.upsert(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(klass.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.upsert(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.upsert(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.upsert(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.upsert(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
    end

    describe 'primary key validation' do
      context 'simple primary key' do
        it 'requires partition key to be specified' do
          klass.create_table

          expect {
            klass.upsert nil, title: 'threethree'
          }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'composite key' do
        it 'requires partition key to be specified' do
          klass_with_composite_key.create_table

          expect {
            klass_with_composite_key.upsert nil, name: 'Alex'
          }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          klass_with_composite_key.create_table
          id = SecureRandom.uuid

          expect {
            klass_with_composite_key.upsert id, nil, name: 'Alex'
          }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
        end
      end
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            klass.upsert(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            klass.upsert(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          klass.upsert(obj.id, title: 'New title')
        end.not_to raise_error
      end

      it 'does not set updated_at if Config.timestamps=true and table timestamps=false', config: { timestamps: true } do
        klass.table timestamps: false

        obj = klass.create(title: 'Old title')
        klass.upsert(obj.id, title: 'New title')

        expect(obj.reload.attributes).not_to have_key(:updated_at)
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        klass_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = klass_with_range.create(title: 'Old', count: '100')
        klass_with_range.upsert(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.upsert(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          klass.upsert(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = klass.create(title: 'New Document')

      expect {
        klass.upsert(obj.id, { title: 'New title', publisher: 'New publisher' })
      }.to raise_error Dynamoid::Errors::UnknownAttribute
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
          field :comment
        end

        payment = Payment.create!

        expect {
          Payment.upsert(payment.id, comment: 'A')
        }.to send_request_matching(:UpdateItem, { TableName: table.arn })
      end
    end
  end
end
