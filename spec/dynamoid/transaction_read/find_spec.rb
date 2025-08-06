# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionRead, '#find' do
  let(:klass) do
    new_class(class_name: 'Document')
  end

  let(:klass_with_composite_key) do
    new_class(class_name: 'Cat') do
      range :age, :integer
    end
  end

  context 'a single primary key provided' do
    context 'simple primary key' do
      it 'finds a model' do
        obj = klass.create!

        result = described_class.execute do |t|
          t.find klass, obj.id
        end

        expect(result).to eql([obj])
      end

      it 'returns multiple models when called multiple times' do
        obj1 = klass.create!
        obj2 = klass.create!

        result = described_class.execute do |t|
          t.find klass, obj1.id
          t.find klass, obj2.id
        end

        expect(result).to eql([obj1, obj2])
      end

      it 'allows multiple model classes to be used' do
        klass2 = new_class(class_name: 'Profile')

        obj1 = klass.create!
        obj2 = klass2.create!

        result = described_class.execute do |t|
          t.find klass, obj1.id
          t.find klass2, obj2.id
        end

        expect(result).to eql([obj1, obj2])
      end

      it 'raises RecordNotFound error when found nothing' do
        klass.create_table

        expect {
          described_class.execute do |t|
            t.find klass, 'wrong-id'
          end
        }.to raise_error(Dynamoid::Errors::RecordNotFound, "Couldn't find Document with primary key \"wrong-id\"")
      end
    end

    context 'composite primary key' do
      it 'finds a model' do
        obj = klass_with_composite_key.create!(age: 12)

        result = described_class.execute do |t|
          t.find klass_with_composite_key, obj.id, range_key: 12
        end

        expect(result).to eql([obj])
      end

      it 'returns multiple models when called multiple times' do
        obj1 = klass_with_composite_key.create!(age: 12)
        obj2 = klass_with_composite_key.create!(age: 32)

        result = described_class.execute do |t|
          t.find klass_with_composite_key, obj1.id, range_key: 12
          t.find klass_with_composite_key, obj2.id, range_key: 32
        end

        expect(result).to eql([obj1, obj2])
      end

      it 'allows multiple model classes to be used' do
        klass_with_composite_key2 = new_class(class_name: 'Profile') do
          range :age, :integer
        end

        obj1 = klass_with_composite_key.create!(age: 12)
        obj2 = klass_with_composite_key2.create!(age: 32)

        result = described_class.execute do |t|
          t.find klass_with_composite_key, obj1.id, range_key: 12
          t.find klass_with_composite_key2, obj2.id, range_key: 32
        end

        expect(result).to eql([obj1, obj2])
      end

      it 'raises RecordNotFound error when found nothing' do
        klass_with_composite_key.create_table

        expect {
          described_class.execute do |t|
            t.find klass_with_composite_key, 'wrong-id', range_key: 100_500
          end
        }.to raise_error(Dynamoid::Errors::RecordNotFound, "Couldn't find Cat with primary key (\"wrong-id\",100500)")
      end

      it 'raises MissingRangeKey when range key is not specified' do
        obj = klass_with_composite_key.create!(age: 12)

        expect {
          described_class.execute do |t|
            t.find klass_with_composite_key, obj.id
          end
        }.to raise_error(Dynamoid::Errors::MissingRangeKey)
      end
    end

    it 'returns persisted? object' do
      obj = klass.create!

      result = described_class.execute do |t|
        t.find klass, obj.id
      end

      obj_found = result[0]
      expect(obj_found).to be_persisted
    end

    context 'field is not declared in document' do
      let(:class_with_not_declared_field) do
        new_class do
          field :name
        end
      end

      before do
        class_with_not_declared_field.create_table
      end

      it 'ignores it without exceptions' do
        Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', name: 'Alex', bod: '1996-12-21')

        obj = class_with_not_declared_field.find('1')
        result = described_class.execute do |t|
          t.find class_with_not_declared_field, '1'
        end

        obj_found = result[0]
        expect(obj_found.id).to eql('1')
        expect(obj_found.name).to eql('Alex')
      end
    end

    describe ':raise_error option' do
      before do
        klass.create_table
      end

      context 'when true' do
        it 'leads to raising RecordNotFound exception if model not found' do
          expect do
            described_class.execute do |t|
              t.find klass, 'blah-blah', raise_error: true
            end
          end.to raise_error(Dynamoid::Errors::RecordNotFound)
        end
      end

      context 'when false' do
        it 'leads to not raising exception if model not found' do
          obj1 = klass.create!
          obj2 = klass.create!

          result = described_class.execute do |t|
            t.find klass, obj1.id
            t.find klass, 'blah-blah', raise_error: false
            t.find klass, obj2.id
          end

          expect(result).to eq [obj1, nil, obj2]
        end
      end
    end

    it 'type casts a partition key value' do
      klass = new_class(partition_key: { name: :published_on, type: :date })
      obj = klass.create!(published_on: '2018-10-07'.to_date)

      result = described_class.execute do |t|
        t.find klass, '2018-10-07'
      end

      expect(result).to eql([obj])
    end

    it 'type casts a sort key value' do
      klass = new_class do
        range :published_on, :date
      end
      obj = klass.create!(published_on: '2018-10-07'.to_date)

      result = described_class.execute do |t|
        t.find klass, obj.id, range_key: '2018-10-07'
      end

      expect(result).to eql([obj])
    end

    it 'uses dumped value of partition key' do
      klass = new_class(partition_key: { name: :published_on, type: :date })
      obj = klass.create!(published_on: '2018-10-07'.to_date)

      result = described_class.execute do |t|
        t.find klass, obj.published_on
      end

      expect(result).to eql([obj])
    end

    it 'uses dumped value of sort key' do
      klass = new_class do
        range :published_on, :date
      end
      obj = klass.create!(published_on: '2018-10-07'.to_date)

      result = described_class.execute do |t|
        t.find klass, obj.id, range_key: obj.published_on
      end

      expect(result).to eql([obj])
    end
  end

  context 'multiple primary keys provided' do
    context 'simple primary key' do
      it 'finds models by an array of keys' do # rubocop:disable RSpec/RepeatedExample
        objects = (1..2).map { klass.create! }
        obj1, obj2 = objects

        result = described_class.execute do |t|
          t.find klass, [obj1.id, obj2.id]
        end

        expect(result).to eq([obj1, obj2])
      end

      it 'finds models by a list of keys' do # rubocop:disable RSpec/RepeatedExample
        objects = (1..2).map { klass.create! }
        obj1, obj2 = objects

        result = described_class.execute do |t|
          t.find klass, [obj1.id, obj2.id]
        end

        expect(result).to eq([obj1, obj2])
      end

      it 'finds by one key' do
        obj = klass.create!

        result = described_class.execute do |t|
          t.find klass, [obj.id]
        end

        expect(result).to eq([obj])
      end

      it 'returns an empty array if an empty array passed' do
        klass.create_table

        result = described_class.execute do |t|
          t.find klass, []
        end

        expect(result).to eql([])
      end

      it 'returns multiple models when called multiple times' do
        objects = (1..4).map { klass.create! }
        obj1, obj2, obj3, obj4 = objects

        result = described_class.execute do |t|
          t.find klass, [obj1.id, obj2.id]
          t.find klass, [obj3.id, obj4.id]
        end

        expect(result).to eq([obj1, obj2, obj3, obj4])
      end

      it 'allows multiple model classes to be used' do
        klass2 = new_class(class_name: 'Profile')

        objects = (1..2).map { klass.create! }
        obj1, obj2 = objects

        objects = (1..2).map { klass2.create! }
        obj3, obj4 = objects

        result = described_class.execute do |t|
          t.find klass, [obj1.id, obj2.id]
          t.find klass2, [obj3.id, obj4.id]
        end

        expect(result).to eql([obj1, obj2, obj3, obj4])
      end

      it 'raises RecordNotFound error when some objects are not found' do
        objects = (1..2).map { klass.create }
        obj1, obj2 = objects

        expect {
          described_class.execute do |t|
            t.find klass, [obj1.id, obj2.id, 'wrong-id']
          end
        }.to raise_error(Dynamoid::Errors::RecordNotFound,
                         "Couldn't find all Documents with primary keys [#{obj1.id.inspect}, #{obj2.id.inspect}, \"wrong-id\"] (found 2 results, but was looking for 3)")
      end

      it 'raises RecordNotFound even if only one primary key provided and no result found' do
        klass.create_table

        expect {
          described_class.execute do |t|
            t.find klass, ['wrong-id']
          end
        }.to raise_error(Dynamoid::Errors::RecordNotFound,
                         "Couldn't find all Documents with primary keys [\"wrong-id\"] (found 0 results, but was looking for 1)")
      end
    end

    context 'composite primary key' do
      it 'finds models by an array of keys' do
        objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
        obj1, obj2 = objects

        result = described_class.execute do |t|
          t.find klass_with_composite_key, [[obj1.id, obj1.age], [obj2.id, obj2.age]]
        end

        expect(result).to eql([obj1, obj2])
      end

      it 'finds models by a list of keys' do
        skip 'still is not implemented'
      end

      it 'finds with one key' do
        obj = klass_with_composite_key.create!(age: 12)

        result = described_class.execute do |t|
          t.find klass_with_composite_key, [[obj.id, obj.age]]
        end

        expect(result).to eql([obj])
      end

      it 'returns an empty array if an empty array passed' do
        klass_with_composite_key.create_table

        result = described_class.execute do |t|
          t.find klass_with_composite_key, []
        end

        expect(result).to eql([])
      end

      it 'returns multiple models when called multiple times' do
        objects = (1..4).map { |i| klass_with_composite_key.create!(age: i) }
        obj1, obj2, obj3, obj4 = objects

        result = described_class.execute do |t|
          t.find klass_with_composite_key, [[obj1.id, obj1.age], [obj2.id, obj2.age]]
          t.find klass_with_composite_key, [[obj3.id, obj3.age], [obj4.id, obj4.age]]
        end

        expect(result).to eql([obj1, obj2, obj3, obj4])
      end

      it 'allows multiple model classes to be used' do
        klass_with_composite_key2 = new_class(class_name: 'Profile') do
          range :age, :integer
        end

        objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
        obj1, obj2 = objects

        objects = (1..2).map { |i| klass_with_composite_key2.create!(age: i) }
        obj3, obj4 = objects

        result = described_class.execute do |t|
          t.find klass_with_composite_key, [[obj1.id, obj1.age], [obj2.id, obj2.age]]
          t.find klass_with_composite_key2, [[obj3.id, obj3.age], [obj4.id, obj4.age]]
        end

        expect(result).to eql([obj1, obj2, obj3, obj4])
      end

      it 'raises RecordNotFound error when some objects are not found' do
        obj = klass_with_composite_key.create!(age: 12)

        expect {
          described_class.execute do |t|
            t.find klass_with_composite_key, [[obj.id, obj.age], ['wrong-id', 100_500]]
          end
        }.to raise_error(
          Dynamoid::Errors::RecordNotFound,
          "Couldn't find all Cats with primary keys [(#{obj.id.inspect},12), (\"wrong-id\",100500)] (found 1 results, but was looking for 2)"
        )
      end

      it 'raises RecordNotFound if only one primary key provided and no result found' do
        klass_with_composite_key.create_table

        expect {
          described_class.execute do |t|
            t.find klass_with_composite_key, [['wrong-id', 100_500]]
          end
        }.to raise_error(
          Dynamoid::Errors::RecordNotFound,
          "Couldn't find all Cats with primary keys [(\"wrong-id\",100500)] (found 0 results, but was looking for 1)"
        )
      end

      it 'raises MissingRangeKey when range key is not specified' do
        obj1, obj2 = klass_with_composite_key.create!([{ age: 1 }, { age: 2 }])

        expect {
          described_class.execute do |t|
            t.find klass_with_composite_key, [obj1.id, obj2.id]
          end
        }.to raise_error(Dynamoid::Errors::MissingRangeKey)
      end
    end

    it 'returns persisted? objects' do
      objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
      obj1, obj2 = objects

      result = described_class.execute do |t|
        t.find klass_with_composite_key, [[obj1.id, obj1.age], [obj2.id, obj2.age]]
      end

      obj1, obj2 = objects
      expect(obj1).to be_persisted
      expect(obj2).to be_persisted
    end

    describe ':raise_error option' do
      context 'when true' do
        it 'leads to raising exception if model not found' do
          obj = klass.create!

          expect do
            described_class.execute do |t|
              t.find klass, [obj.id, 'blah-blah'], raise_error: true
            end
          end.to raise_error(Dynamoid::Errors::RecordNotFound)
        end
      end

      context 'when false' do
        it 'leads to not raising exception if model not found' do
          obj1 = klass.create!
          obj2 = klass.create!

          result = described_class.execute do |t|
            t.find klass, [obj1.id, 'blah-blah', obj2.id], raise_error: false
          end

          expect(result).to eq [obj1, obj2]
        end
      end
    end

    it 'type casts a partition key value' do
      klass = new_class(partition_key: { name: :published_on, type: :date })
      obj1 = klass.create!(published_on: '2018-10-07'.to_date)
      obj2 = klass.create!(published_on: '2018-10-08'.to_date)

      objects = described_class.execute do |t|
        t.find klass, %w[2018-10-07 2018-10-08]
      end

      expect(objects).to contain_exactly(obj1, obj2)
    end

    it 'type casts a sort key value' do
      klass = new_class do
        range :published_on, :date
      end
      obj1 = klass.create!(published_on: '2018-10-07'.to_date)
      obj2 = klass.create!(published_on: '2018-10-08'.to_date)

      objects = described_class.execute do |t|
        t.find klass, [[obj1.id, '2018-10-07'], [obj2.id, '2018-10-08']]
      end

      expect(objects).to contain_exactly(obj1, obj2)
    end

    it 'uses dumped value of partition key' do
      klass = new_class(partition_key: { name: :published_on, type: :date })
      obj1 = klass.create!(published_on: '2018-10-07'.to_date)
      obj2 = klass.create!(published_on: '2018-10-08'.to_date)

      objects = described_class.execute do |t|
        t.find klass, [obj1.published_on, obj2.published_on]
      end

      expect(objects).to contain_exactly(obj1, obj2)
    end

    it 'uses dumped value of sort key' do
      klass = new_class do
        range :published_on, :date
      end
      obj1 = klass.create!(published_on: '2018-10-07'.to_date)
      obj2 = klass.create!(published_on: '2018-10-08'.to_date)

      objects = described_class.execute do |t|
        t.find klass, [[obj1.id, obj1.published_on], [obj2.id, obj2.published_on]]
      end

      expect(objects).to contain_exactly(obj1, obj2)
    end

    context 'field is not declared in document' do
      let(:class_with_not_declared_field) do
        new_class do
          field :name
        end
      end

      before do
        class_with_not_declared_field.create_table
      end

      it 'ignores it without exceptions' do
        Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', dob: '1996-12-21')
        Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '2', dob: '2001-03-14')

        result = described_class.execute do |t|
          t.find class_with_not_declared_field, %w[1 2]
        end

        expect(result.size).to eql 2
        expect(result.map(&:id)).to eql(%w[1 2])
      end
    end
  end

  describe 'callbacks' do
    before do
      ScratchPad.record []
    end

    it 'runs after_initialize callback' do
      klass_with_callback = new_class do
        after_initialize { ScratchPad << 'run after_initialize' }
      end
      object = klass_with_callback.create!

      ScratchPad.record []
      described_class.execute do |t|
        t.find klass_with_callback, object.id
      end

      expect(ScratchPad.recorded).to eql(['run after_initialize'])
    end

    it 'runs after_find callback' do
      klass_with_callback = new_class do
        after_find { ScratchPad << 'run after_find' }
      end
      object = klass_with_callback.create!

      ScratchPad.record []
      described_class.execute do |t|
        t.find klass_with_callback, object.id
      end

      expect(ScratchPad.recorded).to eql(['run after_find'])
    end

    it 'runs callbacks in the proper order' do
      klass_with_callback = new_class do
        after_initialize { ScratchPad << 'run after_initialize' }
        after_find { ScratchPad << 'run after_find' }
      end
      object = klass_with_callback.create!

      ScratchPad.record []
      described_class.execute do |t|
        t.find klass_with_callback, object.id
      end

      # it doesn't match Rails and ActiveRecord, where #after_find is called
      # before #after_initialize
      expect(ScratchPad.recorded).to eql(['run after_initialize', 'run after_find'])
    end
  end
end
