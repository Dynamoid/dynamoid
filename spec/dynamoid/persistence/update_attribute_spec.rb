# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#update_attribute' do
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
        field :name
      end
    end

    it 'updates an attribute value' do
      obj = klass.create!(age: 18)

      expect { obj.update_attribute(:age, 20) }.to change { obj.age }.from(18).to(20)
    end

    it 'persists the updated attribute' do
      obj = klass.create!(age: 18)
      obj.update_attribute(:age, 20)

      expect(klass.find(obj.id).age).to eq(20)
    end

    it 'skips validations' do
      klass_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 0 }
      end

      obj = klass_with_validation.create!(age: 18)
      obj.update_attribute(:age, -1)

      expect(klass_with_validation.find(obj.id).age).to eq(-1)
    end

    it 'returns self' do
      obj = klass.create!(age: 18)
      result = obj.update_attribute(:age, 20)

      expect(result).to eq(obj)
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.update_attribute(:tags, [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty strings as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty strings as nil when store_empty_string_as_nil is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty strings as is when store_empty_string_as_nil is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
    end

    describe 'type casting' do
      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create
        obj.update_attribute(:count, '101')
        expect(obj.attributes[:count]).to eql(101)
        expect(raw_attributes(obj)[:count]).to eql(101)
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now
          obj.update_attribute(:title, 'New title')

          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided value updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now
          obj.update_attribute(:updated_at, updated_at)

          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'works if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')
        obj.update_attribute(:title, 'New title')
        expect(obj.reload.title).to eq('New title')
      end

      it 'does not change updated_at if attribute value is the same' do
        obj = klass.create(title: 'Old title', updated_at: Time.now - 1)
        obj.title = obj.title # rubocop:disable Lint/SelfAssignment

        expect do
          obj.update_attribute(:title, 'Old title')
        end.not_to change { obj.updated_at }
      end
    end

    it 'raises UnknownAttribute for undeclared fields' do
      klass_with_fields = new_class do
        field :age, :integer
        field :name, :string
      end

      obj = klass_with_fields.create!(name: 'Alex', age: 26)

      expect {
        obj.update_attribute(:city, 'Dublin')
      }.to raise_error(Dynamoid::Errors::UnknownAttribute)
    end

    describe 'callbacks' do
      it 'runs before_update callbacks' do
        klass_with_callback = new_class do
          field :name
          before_update { ScratchPad << 'run before_update' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to include('run before_update')
      end

      it 'runs after_update callbacks' do
        klass_with_callback = new_class do
          field :name
          after_update { ScratchPad << 'run after_update' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to include('run after_update')
      end

      it 'runs around_update callbacks' do
        klass_with_callback = new_class do
          field :name
          around_update :around_update_callback
          def around_update_callback
            ScratchPad << 'start around_update'
            yield
            ScratchPad << 'finish around_update'
          end
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to eq(['start around_update', 'finish around_update'])
      end

      it 'runs before_save callbacks' do
        klass_with_callback = new_class do
          field :name
          before_save { ScratchPad << 'run before_save' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to include('run before_save')
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          field :name
          after_save { ScratchPad << 'run after_save' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to include('run after_save')
      end

      it 'runs around_save callbacks' do
        klass_with_callback = new_class do
          field :name
          around_save :around_save_callback
          def around_save_callback
            ScratchPad << 'start around_save'
            yield
            ScratchPad << 'finish around_save'
          end
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to eq(['start around_save', 'finish around_save'])
      end

      it 'skips before_validation callbacks' do
        klass_with_callback = new_class do
          field :name
          before_validation { ScratchPad << 'run before_validation' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).not_to include('run before_validation')
      end

      it 'skips after_validation callbacks' do
        klass_with_callback = new_class do
          field :name
          after_validation { ScratchPad << 'run after_validation' }
        end

        ScratchPad.record []
        obj = klass_with_callback.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).not_to include('run after_validation')
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :name

          before_update { ScratchPad << 'run before_update' }
          after_update { ScratchPad << 'run after_update' }
          around_update :around_update_callback

          before_save { ScratchPad << 'run before_save' }
          after_save { ScratchPad << 'run after_save' }
          around_save :around_save_callback

          def around_save_callback
            ScratchPad << 'start around_save'
            yield
            ScratchPad << 'finish around_save'
          end

          def around_update_callback
            ScratchPad << 'start around_update'
            yield
            ScratchPad << 'finish around_update'
          end
        end

        expected_output = [
          'run before_save',
          'start around_save',
          'run before_update',
          'start around_update',
          'finish around_update',
          'run after_update',
          'finish around_save',
          'run after_save'
        ]

        ScratchPad.record []
        obj = klass_with_callbacks.create(name: 'Alex')
        ScratchPad.record []

        obj.update_attribute(:name, 'Alexey')
        expect(ScratchPad.recorded).to eq(expected_output)
      end
    end

    context 'when a callback aborts saving' do
      it 'aborts updating when callback throws :abort' do
        if ActiveSupport.version < Gem::Version.new('5.0')
          skip "Rails 4.x and below don't support aborting with `throw :abort`"
        end

        klass_with_abort = new_class do
          field :name
          before_update { throw :abort }
        end

        obj = klass_with_abort.create!(name: 'Alex')

        expect {
          obj.update_attribute(:name, 'Alex [Updated]')
        }.not_to change { klass_with_abort.find(obj.id).name }

        expect(obj).to be_persisted
        expect(obj).to be_changed
      end
    end

    context 'concurrent deletion' do
      it 'does not persist changes when simple primary key' do
        obj = klass.create!(age: 21)
        klass.find(obj.id).delete

        obj.update_attribute(:age, 42)
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        obj.update_attribute(:age, 42)
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], name: 'Alex')
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.update_attribute(:name, 'Michael')
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
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

        payment = Payment.create!

        expect {
          payment.update_attribute(:comment, 'A')
        }.to send_request_matching(:UpdateItem, { TableName: table.arn })
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

      it 'updates successfully when GSI partition key is nil' do
        obj = klass_with_gsi.create!(name: 'Alex', age: 42)
        obj.update_attribute(:name, nil)
        expect(obj.reload.name).to eql nil
      end

      it 'updates successfully when GSI sort key is nil' do
        obj = klass_with_gsi.create!(name: 'Alex', age: 42)
        obj.update_attribute(:age, nil)
        expect(obj.reload.age).to eql nil
      end
    end

    describe 'store_attribute_with_nil_value config option' do
      let(:klass) do
        new_class do
          field :age, :integer
        end
      end

      context 'true', config: { store_attribute_with_nil_value: true } do
        it 'keeps document attribute with nil' do
          obj = klass.create!(age: 42)
          obj.update_attribute(:age, nil)

          expect(raw_attributes(obj)).to include(age: nil)
        end
      end

      context 'false', config: { store_attribute_with_nil_value: false } do
        it 'does not keep document attribute with nil' do
          obj = klass.create!(age: 42)
          obj.update_attribute(:age, nil)

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end

      context 'by default', config: { store_attribute_with_nil_value: nil } do
        it 'does not keep document attribute with nil' do
          obj = klass.create!(age: 42)
          obj.update_attribute(:age, nil)

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end
    end

    # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
    it 'allows reserved words as attribute names' do
      klass = new_class do
        field :name
      end
      obj = klass.create!(name: 'Original')
      obj.update_attribute(:name, 'Updated')
      expect(klass.find(obj.id).name).to eq 'Updated'
    end

    # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
    it 'allows reserved words as partition key and sort key' do
      klass = new_class(partition_key: { name: :order }) do
        range :count, :integer
        field :name
      end
      obj = klass.create!(order: 'order-1', count: 1, name: 'Alex')
      obj.update_attribute(:name, 'Michael')
      expect(obj.reload.name).to eq 'Michael'
    end
  end

  describe '#update_attribute!' do
    context 'when a callback aborts saving' do
      it 'raises RecordNotSaved when callback throws :abort' do
        if ActiveSupport.version < Gem::Version.new('5.0')
          skip "Rails 4.x and below don't support aborting with `throw :abort`"
        end

        klass_with_abort = new_class do
          field :name
          before_update { throw :abort }
        end

        obj = klass_with_abort.create!(name: 'Alex')

        expect {
          expect {
            obj.update_attribute!(:name, 'Alex [Updated]')
          }.to raise_error(Dynamoid::Errors::RecordNotSaved)
        }.not_to change { klass_with_abort.find(obj.id).name }

        expect(obj).to be_persisted
        expect(obj).to be_changed
      end
    end
  end
end
