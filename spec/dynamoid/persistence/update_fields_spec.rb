# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.update_fields' do
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

    let(:klass_with_composite_key_and_custom_type) do
      new_class do
        range :tags, :serialized
        field :name
      end
    end

    it 'changes field value' do
      obj = klass.create(title: 'Old title')
      expect do
        klass.update_fields(obj.id, title: 'New title')
      end.to change { klass.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = klass.create(title: 'New Document')
      expect do
        klass.update_fields(obj.id, title: nil)
      end.to change { klass.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = klass.create(title: 'Old title')
      result = klass.update_fields(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'condition specified' do
      describe 'if condition' do
        it 'updates when model matches conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          expect {
            klass.update_fields(obj.id, { title: 'New title' }, if: { version: 1 })
          }.to change { klass.find(obj.id).title }.to('New title')
        end

        it 'does not update when model does not match conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          expect {
            result = klass.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
          }.not_to change { klass.find(obj.id).title }
        end

        it 'returns nil when model does not match conditions' do
          obj = klass.create(title: 'Old title', version: 1)

          result = klass.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
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
            klass.update_fields(obj.id, { title: 'New title' }, { unless_exists: [:version] })
          }.to change { klass.find(obj.id).title }.to('New title')
        end

        it 'does not update when model has specified attribute' do
          obj = klass.create(title: 'Old title', version: 1)
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

          expect {
            result = klass.update_fields(obj.id, { title: 'New title' }, { unless_exists: [:version] })
          }.not_to change { klass.find(obj.id).title }
        end

        context 'when multiple attribute names' do
          it 'updates when item does not have all the specified attributes' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = klass.create(title: 'Old title')
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :created_at, :updated_at)

            expect {
              klass.update_fields(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.to change { klass.find(obj.id).title }.to('New title')
          end

          it 'does not update when model has all the specified attributes' do
            obj = klass.create(title: 'Old title', version: 1, published_on: '2018-02-23'.to_date)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :published_on, :created_at, :updated_at)

            expect {
              result = klass.update_fields(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.not_to change { klass.find(obj.id).title }
          end

          it 'does not update when model has at least one specified attribute' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = klass.create(title: 'Old title', version: 1)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

            expect {
              result = klass.update_fields(obj.id, { title: 'New title' }, { unless_exists: %i[version published_on] })
            }.not_to change { klass.find(obj.id).title }
          end
        end
      end
    end

    it 'does not create new document if it does not exist yet' do
      klass.create_table

      expect do
        klass.update_fields('some-fake-id', title: 'Title')
      end.not_to change(klass, :count)
    end

    it 'accepts range key if it is declared' do
      klass_with_range = new_class do
        field :title
        range :category
      end

      obj = klass_with_range.create(category: 'New')

      expect do
        klass_with_range.update_fields(obj.id, 'New', title: '[Updated]')
      end.to change {
        klass_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of partition key to update item' do
      klass = new_class(partition_key: { name: :published_on, type: :date }) do
        field :title
      end

      obj = klass.create!(published_on: '2018-10-07'.to_date, title: 'Old')
      klass.update_fields('2018-10-07'.to_date, title: 'New')

      expect(obj.reload.title).to eq 'New'
    end

    it 'uses dumped value of sort key to update item' do
      klass_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = klass_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      klass_with_range.update_fields(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = klass.create
      klass.update_fields(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(klass.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.update_fields(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.update_fields(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.update_fields(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.update_fields(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
    end

    describe 'primary key validation' do
      context 'simple primary key' do
        it 'requires partition key to be specified' do
          obj = klass.create!(title: 'Alex')

          expect {
            klass.update_fields nil, title: 'Alex [Updated]'
          }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'composite key' do
        it 'requires partition key to be specified' do
          obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

          expect {
            klass_with_composite_key.update_fields nil, 3, name: 'Alex [Updated]'
          }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

          expect {
            klass_with_composite_key.update_fields obj.id, nil, name: 'Alex [Updated]'
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
            klass.update_fields(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            klass.update_fields(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          klass.update_fields(obj.id, title: 'New title')
        end.not_to raise_error
      end

      it 'does not set updated_at if Config.timestamps=true and table timestamps=false', config: { timestamps: true } do
        klass.table timestamps: false

        obj = klass.create(title: 'Old title')
        klass.update_fields(obj.id, title: 'New title')

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
        klass_with_range.update_fields(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update_fields(obj.id, count: '101')
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
          klass.update_fields(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = klass.create(title: 'New Document')

      expect {
        klass.update_fields(obj.id, { title: 'New title', publisher: 'New publisher' })
      }.to raise_error Dynamoid::Errors::UnknownAttribute
    end

    context 'when a model was concurrently deleted' do
      it 'does not persist changes when simple primary key' do
        obj = klass.create!(title: 'Title')
        klass.find(obj.id).delete

        klass.update_fields(obj.id, title: 'New title')
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)
        klass_with_composite_key.find(obj.id, range_key: obj.age).delete

        klass_with_composite_key.update_fields obj.id, obj.age, name: 'Alex [Updated]'
        expect(klass_with_composite_key.exists?(id: obj.id, age: obj.age)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], name: 'Alex')
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        klass_with_composite_key_and_custom_type.update_fields obj.id, obj.tags, name: 'Alex [Updated]'
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end
  end
end
