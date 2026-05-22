# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.import' do
    let(:klass) do
      new_class do
        field :city
      end
    end

    it 'creates multiple items' do
      klass.create_table

      expect do
        klass.import([{ city: 'Chicago' }, { city: 'New York' }])
      end.to change(klass, :count).by(2)
    end

    it 'returns created items' do
      klass.create_table

      addresses = klass.import([{ city: 'Chicago' }, { city: 'New York' }])
      expect(addresses[0].city).to eq('Chicago')
      expect(addresses[1].city).to eq('New York')
    end

    it 'skips validations' do
      klass = new_class do
        field :city
        validates :city, presence: true
      end
      klass.create_table

      addresses = klass.import([{ city: nil }, { city: 'Chicago' }])
      expect(addresses[0].persisted?).to be true
      expect(addresses[1].persisted?).to be true
    end

    describe 'callbacks' do
      it 'skips validation callbacks' do
        klass = new_class do
          field :city
          validates :city, presence: true

          before_validation { ScratchPad << 'run before_validation' }
          after_validation { ScratchPad << 'run after_validation' }
        end
        klass.create_table
        ScratchPad.record []

        klass.import([{ city: 'Chicago' }])
        expect(ScratchPad.recorded).to be_empty
      end

      it 'skips save callbacks' do
        klass = new_class do
          field :city
          before_save { ScratchPad << 'run before_save' }
          after_save { ScratchPad << 'run after_save' }
        end
        klass.create_table
        ScratchPad.record []

        klass.import([{ city: 'Chicago' }])
        expect(ScratchPad.recorded).to be_empty
      end

      it 'skips create callbacks' do
        klass = new_class do
          field :city
          before_create { ScratchPad << 'run before_create' }
          after_create { ScratchPad << 'run after_create' }
        end
        klass.create_table
        ScratchPad.record []

        klass.import([{ city: 'Chicago' }])
        expect(ScratchPad.recorded).to be_empty
      end
    end

    it 'makes batch operation' do
      expect(Dynamoid.adapter).to receive(:batch_write_item).and_call_original
      klass.create_table
      klass.import([{ city: 'Chicago' }, { city: 'New York' }])
    end

    it 'supports empty containers in serialized fields' do
      klass_with_serialized = new_class do
        field :favorite_colors, :serialized
      end
      klass_with_serialized.create_table

      user, = klass_with_serialized.import([{ favorite_colors: Set.new }])
      expect(user.reload.favorite_colors).to eq Set.new
    end

    it 'supports empty arrays' do
      klass_with_array = new_class do
        field :todo_list, :array
      end
      klass_with_array.create_table

      user, = klass_with_array.import([{ todo_list: [] }])
      expect(user.reload.todo_list).to eq []
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end
      klass_with_set.create_table

      tweet, = klass_with_set.import([{ tags: Set[] }])
      expect(tweet.reload.tags).to eq nil
    end

    it 'saves empty strings as nil' do
      klass.create_table

      address, = klass.import([{ city: '' }])
      expect(address.reload.city).to eq nil
    end

    it 'saves empty strings as nil when store_empty_string_as_nil is true', config: { store_empty_string_as_nil: true } do
      klass.create_table
      address, = klass.import([{ city: '' }])
      expect(address.reload.city).to eq nil
    end

    it 'saves empty strings as is when store_empty_string_as_nil is false', config: { store_empty_string_as_nil: false } do
      klass.create_table
      address, = klass.import([{ city: '' }])

      expect(address.reload.city).to eq ''
      expect(raw_attributes(address)[:city]).to eql ''
    end

    it 'saves nil attributes' do
      klass.create_table
      address, = klass.import([{ city: nil }])
      expect(address.reload.city).to eq nil
    end

    it 'supports nil containers' do
      klass_with_array = new_class do
        field :todo_list, :array
      end
      klass_with_array.create_table

      obj, = klass_with_array.import([{ todo_list: nil }])
      expect(obj.reload.todo_list).to eq nil
    end

    describe 'timestamps' do
      let(:klass) do
        new_class
      end

      before do
        klass.create_table
      end

      it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          time_now = Time.now
          obj, = klass.import([{}])

          expect(obj.created_at.to_i).to eql(time_now.to_i)
          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          created_at = updated_at = Time.now
          obj, = klass.import([{ created_at: created_at, updated_at: updated_at }])

          expect(obj.created_at.to_i).to eql(created_at.to_i)
          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        expect {
          klass.import([{}])
        }.to change(klass, :count).by(1)
      end
    end

    it 'dumps attribute values' do
      klass = new_class do
        field :active, :boolean, store_as_native_boolean: false
      end
      klass.create_table

      objects = klass.import([{ active: false }])
      obj = objects[0]
      obj.save!
      expect(raw_attributes(obj)[:active]).to eql('f')
    end

    it 'type casts attributes' do
      klass = new_class do
        field :count, :integer
      end
      klass.create_table

      objects = klass.import([{ count: '101' }])
      obj = objects[0]
      expect(obj.attributes[:count]).to eql(101)
      expect(raw_attributes(obj)[:count]).to eql(101)
    end

    it 'marks all the attributes as not changed/dirty' do
      klass = new_class do
        field :count, :integer
      end
      klass.create_table

      objects = klass.import([{ count: '101' }])
      obj = objects[0]
      expect(obj.changed?).to eql false
    end

    context 'backoff is specified' do
      let(:backoff_strategy) do
        ->(_) { -> { @counter += 1 } }
      end

      before do
        @old_backoff = Dynamoid.config.backoff
        @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

        @counter = 0
        Dynamoid.config.backoff_strategies[:simple] = backoff_strategy
        Dynamoid.config.backoff = { simple: nil }
      end

      after do
        Dynamoid.config.backoff = @old_backoff
        Dynamoid.config.backoff_strategies = @old_backoff_strategies
      end

      it 'creates multiple items' do
        klass.create_table

        expect do
          klass.import([{ city: 'Chicago' }, { city: 'New York' }])
        end.to change(klass, :count).by(2)
      end

      it 'uses specified backoff when some items are not processed' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        items = (1..3).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        klass.import(items)
        expect(@counter).to eq 2
      end

      it 'uses new backoff after successful call without unprocessed items' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        # batch_write_item processes up to 15 items at once
        # so we emulate 4 calls with items
        items = (1..50).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        expect(backoff_strategy).to receive(:call).twice.and_call_original
        klass.import(items)
        expect(@counter).to eq 2
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      before do
        klass.create_table
      end

      it 'works well with hash keys of any type' do
        a = nil
        expect {
          a, = klass.import([{ hash: { 1 => :b } }])
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end

    context 'when table arn is specified', remove_constants: [:Payment] do
      it 'uses the table ARN', config: { create_table_on_save: false } do
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

        expect {
          Payment.import([{ comment: 'A' }, { comment: 'B' }])
        }.to send_request_matching(:BatchWriteItem, { RequestItems: { table.arn => anything } })
      end
    end

    # See https://github.com/Dynamoid/dynamoid/issues/885 for details
    context 'Global Secondary Index' do
      let(:klass_with_gsi) do
        new_class do
          field :name
          field :age, :number

          global_secondary_index hash_key: :name, range_key: :age
        end
      end

      before do
        klass_with_gsi.create_table
      end

      it 'imports successfully when a GSI partition key is nil' do
        expect do
          klass_with_gsi.import([{ name: nil, age: 42 }])
        end.to change(klass_with_gsi, :count).by(1)

        obj = klass_with_gsi.find(klass_with_gsi.first.id)
        expect(obj.name).to eql nil
        expect(obj.age).to eql 42
      end

      it 'imports successfully when a GSI sort key is nil' do
        expect do
          klass_with_gsi.import([{ name: 'Alex', age: nil }])
        end.to change(klass_with_gsi, :count).by(1)

        obj = klass_with_gsi.find(klass_with_gsi.first.id)
        expect(obj.name).to eql 'Alex'
        expect(obj.age).to eql nil
      end
    end

    describe 'store_attribute_with_nil_value config option' do
      let(:klass) do
        new_class do
          field :age, :integer
        end
      end

      before do
        klass.create_table
      end

      context 'true', config: { store_attribute_with_nil_value: true } do
        it 'keeps document attribute with nil' do
          objects = klass.import([{ age: nil }])
          obj = objects[0]

          expect(raw_attributes(obj)).to include(age: nil)
        end
      end

      context 'false', config: { store_attribute_with_nil_value: false } do
        it 'does not keep document attribute with nil' do
          objects = klass.import([{ age: nil }])
          obj = objects[0]

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end

      context 'by default', config: { store_attribute_with_nil_value: nil } do
        it 'does not keep document attribute with nil' do
          objects = klass.import([{ age: nil }])
          obj = objects[0]

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end
    end
  end
end
