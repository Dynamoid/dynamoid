# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#touch' do
    let(:klass) do
      new_class
    end

    let(:klass_with_composite_key) do
      new_class do
        range :name
      end
    end

    let(:klass_with_composite_key_and_custom_type) do
      new_class do
        range :tags, :serialized
      end
    end

    it 'sets updated_at to current time' do
      obj = klass.create!

      travel 1.hour do
        obj.touch
        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'saves updated_at' do
      obj = klass.create!

      travel 1.hour do
        obj.touch

        obj_persisted = klass.find(obj.id)
        expect(obj_persisted.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'returns self' do
      obj = klass.create!
      expect(obj.touch).to eq obj
    end

    it 'supports custom time' do
      obj = klass.create!

      time = Time.now + 1.day
      obj.touch(time: time)

      obj_persisted = klass.find(obj.id)
      expect(obj.updated_at.to_i).to eq(time.to_i)
      expect(obj_persisted.updated_at.to_i).to eq(time.to_i)
    end

    it 'supports additional timestamp attributes' do
      klass = new_class do
        field :tagged_at, :datetime
        field :logged_in_at, :datetime
      end
      obj = klass.create

      travel 1.hour do
        obj.touch(:tagged_at, :logged_in_at)

        obj_persisted = klass.find(obj.id)

        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
        expect(obj_persisted.updated_at.to_i).to eq(Time.now.to_i)

        expect(obj.tagged_at.to_i).to eq(Time.now.to_i)
        expect(obj_persisted.tagged_at.to_i).to eq(Time.now.to_i)

        expect(obj.logged_in_at.to_i).to eq(Time.now.to_i)
        expect(obj_persisted.logged_in_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'skips other changed attributes' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')
      obj.name = 'Michael'

      travel 1.hour do
        obj.touch

        obj_persisted = klass.find(obj.id)
        expect(obj_persisted.name).to eq 'Alex'
      end
    end

    it 'skips validations' do
      klass_with_validation = new_class do
        field :name
        validates :name, length: { minimum: 4 }
      end

      obj = klass_with_validation.create(name: 'Theodor')
      obj.name = 'Mo'

      travel 1.hour do
        obj.touch

        obj_persisted = klass_with_validation.find(obj.id)
        expect(obj_persisted.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'raises error for new record' do
      obj = klass.new

      expect {
        obj.touch
      }.to raise_error(Dynamoid::Errors::Error, 'cannot touch on a new or destroyed record object')
    end

    describe 'primary key validation' do
      context 'with simple primary key' do
        it 'requires partition key to be specified' do
          obj = klass.create!
          obj.id = nil
          expect { obj.touch }.to raise_error(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'with composite key' do
        it 'requires partition key to be specified' do
          obj = klass_with_composite_key.create!(name: 'Alex')
          obj.id = nil
          expect { obj.touch }.to raise_error(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          obj = klass_with_composite_key.create!(name: 'Alex')
          obj.name = nil
          expect { obj.touch }.to raise_error(Dynamoid::Errors::MissingRangeKey)
        end
      end
    end

    describe 'callbacks' do
      it 'runs after_touch callbacks' do
        klass_with_callbacks = new_class do
          after_touch { ScratchPad << 'run after_touch' }
        end

        ScratchPad.record []
        obj = klass_with_callbacks.create!

        ScratchPad.clear
        obj.touch

        expect(ScratchPad.recorded).to include('run after_touch')
      end

      it 'skips other callbacks' do
        klass_with_callbacks = new_class do
          before_validation { ScratchPad << 'run before_validation' }
          after_validation { ScratchPad << 'run after_validation' }
          before_save { ScratchPad << 'run before_save' }
          after_save { ScratchPad << 'run after_save' }
          before_update { ScratchPad << 'run before_update' }
          after_update { ScratchPad << 'run after_update' }
        end

        ScratchPad.record []
        obj = klass_with_callbacks.create

        ScratchPad.clear
        obj.touch

        expect(ScratchPad.recorded).to be_empty
      end
    end

    context 'with concurrent deletion' do
      it 'skips changes for simple primary key' do
        obj = klass.create!
        klass.find(obj.id).delete

        obj.touch
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'skips changes for composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex')
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        obj.touch
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'skips changes for composite primary key and sort key of type not supported natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b])
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.touch
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end

    # see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html
    it 'allows reserved words as partition key and sort key' do
      klass = new_class(partition_key: { name: :order }) do
        range :count, :integer
      end
      obj = klass.create!(order: 'order-1', count: 1)
      obj.touch
      expect(obj.reload.updated_at).to be_present
    end
  end
end
