# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#update_fields' do
  let(:klass) do
    new_class do
      field :name
      field :record_count, :integer
      field :favorite_numbers, :set, of: :integer
      field :favorite_names, :set, of: :string
    end
  end

  let(:klass_with_composite_key) do
    new_class do
      range :age, :integer
      field :name
    end
  end

  it 'persists changes in already persisted model' do
    obj = klass.create!(name: 'Alex')

    described_class.execute do |t|
      t.update_fields klass, obj.id, name: 'Alex [Updated]'
    end

    obj_loaded = klass.find(obj.id)
    expect(obj_loaded.name).to eql 'Alex [Updated]'
    expect(obj).not_to be_changed
  end

  # TODO
  it 'can be called without attributes to modify'

  it 'returns nil' do
    obj = klass.create!(name: 'Alex')

    result = true
    described_class.execute do |t|
      result = t.update_fields klass, obj.id, name: 'Alex [Updated]'
    end

    expect(result).to eql nil
  end

  it 'raises an UnknownAttribute error when adding an attribute that is not declared in the model' do
    obj = klass.create!(name: 'Alex')

    expect {
      described_class.execute do |t|
        t.update_fields(klass, obj.id, age: 26)
      end
    }.to raise_error Dynamoid::Errors::UnknownAttribute
  end

  describe 'primary key schema' do
    context 'simple primary key' do
      it 'persists changes in already persisted model' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id, name: 'Alex [Updated]'
          end
        }.to change { klass.find(obj.id).name }.to('Alex [Updated]')
      end
    end

    context 'composite key' do
      it 'persists changes in already persisted model' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |t|
            t.update_fields klass_with_composite_key, obj.id, obj.age, name: 'Alex [Updated]'
          end
        }.to change { obj.reload.name }.to('Alex [Updated]')
      end
    end
  end

  describe 'primary key validation' do
    context 'simple primary key' do
      it 'requires partition key to be specified' do
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |t|
            t.update_fields klass_with_composite_key, nil, name: 'Alex [Updated]'
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end
    end

    context 'composite key' do
      it 'requires partition key to be specified' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |t|
            t.update_fields klass_with_composite_key, nil, 3, name: 'Alex [Updated]'
          end
        }.to raise_exception(Dynamoid::Errors::MissingHashKey)
      end

      it 'requires sort key to be specified' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 3)

        expect {
          described_class.execute do |t|
            t.update_fields klass_with_composite_key, obj.id, nil, name: 'Alex [Updated]'
          end
        }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
      end
    end
  end

  describe 'timestamps' do
    it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
      obj = klass.create!

      travel 1.hour do
        time_now = Time.now

        described_class.execute do |t|
          t.update_fields klass, obj.id, name: 'Alex [Updated]'
        end

        obj.reload
        expect(obj.updated_at.to_i).to eql time_now.to_i
      end
    end

    it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
      obj = klass.create!

      travel 1.hour do
        created_at = updated_at = Time.now

        described_class.execute do |t|
          t.update_fields klass, obj.id, created_at: created_at, updated_at: updated_at
        end

        obj.reload
        expect(obj.created_at.to_i).to eql created_at.to_i
        expect(obj.updated_at.to_i).to eql updated_at.to_i
      end
    end

    it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
      obj = klass.create!

      expect {
        described_class.execute do |t|
          t.update_fields klass, obj.id, name: 'Alex [Updated]'
        end
      }.not_to raise_error
    end

    it 'does not raise error if no changes and Config.timestamps=false', config: { timestamps: false } do
      obj = klass.create!

      expect {
        described_class.execute do |t|
          t.update_fields klass, obj.id, {}
        end
      }.not_to raise_error
    end
  end

  context 'when an issue detected on the DynamoDB side' do
    it 'rolls back the changes when model does not exist' do
      obj1 = klass.create!(name: 'one')
      klass.find(obj1.id).delete
      obj2 = nil

      expect {
        described_class.execute do |t|
          t.update_fields klass, obj1.id, { name: 'one [updated]' }
          obj2 = t.create klass, name: 'two'
        end
      }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

      expect(klass.count).to eql 0
      expect(obj2).not_to be_persisted
    end
  end

  describe 'callbacks' do
    it 'does not run any callback' do
      klass_with_callbacks = new_class do
        field :name

        before_validation { ScratchPad << 'run before_validation' }
        after_validation { ScratchPad << 'run after_validation' }

        before_create { ScratchPad << 'run before_create' }
        after_create { ScratchPad << 'run after_create' }
        around_create :around_create_callback

        before_save { ScratchPad << 'run before_save' }
        after_save { ScratchPad << 'run after_save' }
        around_save :around_save_callback

        before_destroy { ScratchPad << 'run before_destroy' }
        after_destroy { ScratchPad << 'run after_destroy' }
        around_destroy :around_destroy_callback

        def around_create_callback
          ScratchPad << 'start around_create'
          yield
          ScratchPad << 'finish around_create'
        end

        def around_save_callback
          ScratchPad << 'start around_save'
          yield
          ScratchPad << 'finish around_save'
        end

        def around_destroy_callback
          ScratchPad << 'start around_destroy'
          yield
          ScratchPad << 'finish around_destroy'
        end
      end

      ScratchPad.record []
      obj = klass_with_callbacks.create!(name: 'Alex')
      ScratchPad.clear

      described_class.execute do |t|
        t.update_fields klass_with_callbacks, obj.id, name: 'Alex [Updated]'
      end

      expect(ScratchPad.recorded).to eql([])
    end
  end

  context 'given a block' do
    describe 'add' do
      it 'increments numeric attribute' do
        klass = new_class do
          field :age, :integer
        end

        obj = klass.create!(age: 10)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add age: 1
          end
        end

        expect(obj.reload.age).to eql 11
      end

      it 'decrements numeric attribute if argument is negative' do
        klass = new_class do
          field :age, :integer
        end

        obj = klass.create!(age: 10)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add age: -1
          end
        end

        expect(obj.reload.age).to eql 9
      end

      it 'increments not initialized numeric attribute as it was 0' do
        klass = new_class do
          field :age, :integer
        end

        obj = klass.create!

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add age: 1
          end
        end

        expect(obj.reload.age).to eql 1
      end

      it 'adds a single element into a set' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: ['tag1'])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: 'tag2'
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag1', 'tag2')
      end

      it 'adds multiple elements into a set' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: ['tag1'])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: %w[tag2 tag3]
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag1', 'tag2', 'tag3')
      end

      it 'adds an element into a not initialized set as it was empty' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: ['tag']
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag')
      end

      it 'supports multiple attributes' do
        klass = new_class do
          field :age, :integer
          field :items_count, :integer
        end

        obj = klass.create!(age: 10, items_count: 20)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add age: 1, items_count: 1
          end
        end

        obj.reload
        expect(obj.age).to eql 11
        expect(obj.items_count).to eql 21
      end

      it 'adds elements into a set of strings' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: ['tag1'])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: ['tag2']
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag1', 'tag2')
      end

      it 'adds elements into a set of numbers' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: [1])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: [2]
          end
        end

        expect(obj.reload.tags).to contain_exactly(1, 2)
      end

      it 'adds elements into a set of binary' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: [StringIO.new('tag1')])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add tags: [StringIO.new('tag2')]
          end
        end

        tags = obj.reload.tags
        expect(tags.map(&:string)).to contain_exactly('tag1', 'tag2')
      end

      # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
      it 'allows reserved words as attribute names' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create!(count: 10)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.add count: 1
          end
        end

        expect(obj.reload.count).to eql 11
      end

      it "raises UnknownAttribute when an attribute name isn't declared as a field" do
        klass = new_class
        obj = klass.create!

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add age: 1
            end
          end
        }.to raise_error(Dynamoid::Errors::UnknownAttribute)
      end

      it "raises Aws::DynamoDB::Errors::ValidationException if numeric attribute but argument isn't a number" do
        klass = new_class do
          field :age, :integer
        end

        obj = klass.create!(age: 10)

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add age: 'abc'
            end
          end
        }.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'Invalid UpdateExpression: Incorrect operand type for operator or function; operator: ADD, operand type: STRING, typeSet: ALLOWED_FOR_ADD_OPERAND')
      end

      it "raises Aws::DynamoDB::Errors::ValidationException if attribute is a set of strings but argument isn't a string" do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: ['tag1'])

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add tags: [1]
            end
          end
        }.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'An operand in the update expression has an incorrect data type')
      end

      it "raises Aws::DynamoDB::Errors::ValidationException if attribute is a set of numbers but argument isn't a number" do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: [1])

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add tags: ['tag2']
            end
          end
        }.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'An operand in the update expression has an incorrect data type')
      end

      it "raises Aws::DynamoDB::Errors::ValidationException if attribute is a set of binary but argument isn't a binary" do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: [StringIO.new('tag1')])

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add tags: ['tag2']
            end
          end
        }.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'An operand in the update expression has an incorrect data type')
      end

      it "raises Aws::DynamoDB::Errors::ValidationException if attribute isn't a number or a set" do
        klass = new_class do
          field :tags, :string
        end

        obj = klass.create!(tags: 'tag1')

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.add tags: ['tag2']
            end
          end
        }.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'Invalid UpdateExpression: Incorrect operand type for operator or function; operator: ADD, operand type: LIST, typeSet: ALLOWED_FOR_ADD_OPERAND')
      end
    end

    describe 'set' do
      it 'assigns attribute a new value' do
        klass = new_class do
          field :name
        end

        obj = klass.create!(name: 'Alex')

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.set name: 'Michael'
          end
        end

        expect(obj.reload.name).to eql 'Michael'
      end

      it 'supports multiple attributes' do
        klass = new_class do
          field :name
          field :age, :integer
        end

        obj = klass.create!(name: 'Alex', age: 10)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.set name: 'Michael', age: 21
          end
        end

        obj.reload
        expect(obj.name).to eql 'Michael'
        expect(obj.age).to eql 21
      end

      # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
      it 'allows reserved words as attribute names' do
        klass = new_class do
          field :from
        end

        obj = klass.create!(from: 'docs.aws.amazon.com')

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.set from: 'github.com'
          end
        end

        expect(obj.reload.from).to eql 'github.com'
      end

      it "raises UnknownAttribute when an attribute name isn't declared as a field" do
        klass = new_class
        obj = klass.create!

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.set name: 'Michael'
            end
          end
        }.to raise_error(Dynamoid::Errors::UnknownAttribute)
      end
    end

    describe 'delete' do
      it 'removes a single element from a set' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: %w[tag1 tag2])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.delete tags: 'tag2'
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag1')
      end

      it 'removes multiple elements from a set' do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: %w[tag1 tag2 tag3])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.delete tags: %w[tag1 tag2]
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag3')
      end

      it 'supports multiple attributes' do
        klass = new_class do
          field :tags, :set
          field :types, :set
        end

        obj = klass.create!(tags: %w[tag1 tag2], types: %w[type1 type2])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.delete tags: ['tag2'], types: ['type2']
          end
        end

        obj.reload
        expect(obj.tags).to contain_exactly('tag1')
        expect(obj.types).to contain_exactly('type1')
      end

      # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
      it 'allows reserved words as attribute names' do
        klass = new_class do
          field :parameters, :set
        end

        obj = klass.create!(parameters: %w[param1 param2])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.delete parameters: 'param2'
          end
        end

        expect(obj.reload.parameters).to contain_exactly('param1')
      end

      it "raises UnknownAttribute when an attribute name isn't declared as a field" do
        klass = new_class
        obj = klass.create!(tags: %w[tag1 tag2])

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.delete tags: 'tag2'
            end
          end
        }.to raise_error(Dynamoid::Errors::UnknownAttribute)
      end

      it "does nothing if element to remove isn't present in a set" do
        klass = new_class do
          field :tags, :set
        end

        obj = klass.create!(tags: %w[tag1 tag2])

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.delete tags: 'tag3'
          end
        end

        expect(obj.reload.tags).to contain_exactly('tag1', 'tag2')
      end
    end

    describe 'remove' do
      it 'assigns attribute the nil value' do
        klass = new_class do
          field :name
        end

        obj = klass.create!(name: 'Alex')

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.remove :name
          end
        end

        expect(obj.reload.name).to eql nil
      end

      it 'supports multiple attributes' do
        klass = new_class do
          field :name
          field :age
        end

        obj = klass.create!(name: 'Alex', age: 30)

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.remove :name, :age
          end
        end

        expect(obj.reload.name).to eql nil
        expect(obj.reload.age).to eql nil
      end

      it 'removes completely an attribute from an item' do
        klass = new_class do
          field :name
        end
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.remove :name
            end
          end
        }.to change { raw_attributes(obj)[:name] }.from('Alex').to(nil)
      end

      # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
      it 'allows reserved words as attribute names' do
        klass = new_class do
          field :from
        end

        obj = klass.create!(from: 'github.com')

        described_class.execute do |t|
          t.update_fields klass, obj.id do |u|
            u.remove :from
          end
        end

        expect(obj.reload.from).to eql nil
      end

      it "raises UnknownAttribute when an attribute name isn't declared as a field" do
        klass = new_class
        obj = klass.create!(name: 'Alex')

        expect {
          described_class.execute do |t|
            t.update_fields klass, obj.id do |u|
              u.remove :name
            end
          end
        }.to raise_error(Dynamoid::Errors::UnknownAttribute)
      end
    end
  end
end
