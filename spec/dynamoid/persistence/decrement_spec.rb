# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#decrement' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    it 'decrements an attribute by 1 by default' do
      obj = klass.new(age: 21)

      expect { obj.decrement(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'treats nil as zero' do
      obj = klass.new(age: nil)

      expect { obj.decrement(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'decrements by a specified amount' do
      obj = klass.new(age: 21)

      expect { obj.decrement(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'returns self' do
      obj = klass.new(age: 21)

      expect(obj.decrement(:age)).to eql(obj)
    end

    it 'does not persist changes' do
      obj = klass.new(age: 21)
      obj.decrement(:age)

      expect(obj).to be_new_record
    end
  end

  describe '#decrement!' do
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

    it 'decrements an attribute by 1 by default' do
      obj = klass.create!(age: 21)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'treats nil as zero' do
      obj = klass.create!(age: nil)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'decrements by a specified amount' do
      obj = klass.create!(age: 21)

      expect { obj.decrement!(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'persists the updated attribute' do
      obj = klass.create!(age: 21)
      obj.decrement!(:age, 10)
      expect(obj.reload.age).to eq 11
    end

    it 'does not persist other dirty attributes' do
      klass = new_class do
        field :age, :integer
        field :title
      end

      obj = klass.create!(age: 21, title: 'title')
      obj.title = 'new title'
      obj.decrement!(:age)

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
      obj.decrement!(:age)

      expect(obj.title).to eq 'new title'
      expect(obj.title_changed?).to eq true
    end

    it 'returns self' do
      obj = klass.create!(age: 21)
      expect(obj.decrement!(:age, 10)).to eq obj
    end

    it 'clears the dirty state of the decremented attribute' do
      obj = klass.create!(age: 21)
      obj.decrement!(:age, 10)

      expect(obj.age_changed?).to eq false
    end

    it 'skips validations' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end

      obj = class_with_validation.create!(age: 20)
      obj.decrement!(:age, 7)
      expect(obj.valid?).to eq false
      expect(obj.reload.age).to eq 13
    end

    it 'skips save callbacks' do
      ScratchPad.record []
      klass = new_class do
        field :age, :integer
        before_save { ScratchPad << 'run before_save' }
      end

      obj = klass.create!(age: 21)
      ScratchPad.clear
      obj.decrement!(:age, 10)
      expect(ScratchPad.recorded).to be_empty
    end

    it "raises UnknownAttribute when an attribute name isn't declared as a field" do
      obj = klass.create!
      expect { obj.decrement!(:unknown) }.to raise_error(Dynamoid::Errors::UnknownAttribute)
    end

    it 'allows reserved words as attribute names' do
      klass = new_class do
        field :counter, :integer
      end
      obj = klass.create!(counter: 10)
      obj.decrement!(:counter, 1)
      expect(obj.reload.counter).to eq(9)
    end

    it 'supports models with a sort key' do
      klass_with_sort_key = new_class do
        range :name
        field :age, :integer
      end

      obj = klass_with_sort_key.create!(name: 'Alex', age: 21)
      obj.decrement!(:age, 10)
      expect(obj.reload.age).to eq 11
    end

    context 'when :touch option passed' do
      it 'updates updated_at when touch: true' do
        obj = klass.create!(age: 21, updated_at: Time.now - 1.day)

        expect { obj.decrement!(:age) }.not_to change { obj.reload.updated_at }
        expect { obj.decrement!(:age, touch: true) }.to change { obj.reload.updated_at }
      end

      it 'updates specified attributes alongside updated_at' do
        klass = new_class do
          field :age, :integer
          field :viewed_at, :datetime
        end

        obj = klass.create!(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

        expect do
          expect do
            obj.decrement!(:age, touch: [:viewed_at])
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

        obj.decrement!(:age, touch: true)
        expect(ScratchPad.recorded).to eq(['run after_touch'])
      end
    end

    describe 'primary key validation' do
      context 'with simple primary key' do
        it 'requires partition key to be specified' do
          obj = klass.new
          expect { obj.decrement!(:age) }.to raise_error(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'with composite key' do
        it 'requires partition key to be specified' do
          obj = klass_with_composite_key.new(name: 'Alex')
          expect { obj.decrement!(:age) }.to raise_error(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          obj = klass_with_composite_key.new(id: '1')
          expect { obj.decrement!(:age) }.to raise_error(Dynamoid::Errors::MissingRangeKey)
        end
      end
    end

    context 'when a model was concurrently deleted' do
      it 'does not persist changes for a simple primary key' do
        obj = klass.create!(age: 21)
        klass.find(obj.id).delete

        obj.decrement!(:age)
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes for a composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        obj.decrement!(:age)
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'does not persist changes when sort key type is not supported natively' do
        obj = klass_with_composite_key_and_custom_type.create!(name: 'Alex', tags: %w[a b], age: 21)
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.decrement!(:age)
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
          field :amount, :integer
        end

        payment = Payment.create!

        expect {
          payment.decrement!(:amount)
        }.to send_request_matching(:UpdateItem, { TableName: table.arn })
      end
    end
  end
end
