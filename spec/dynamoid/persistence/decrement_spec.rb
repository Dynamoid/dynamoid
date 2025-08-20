# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#decrement' do
    let(:document_class) do
      new_class do
        field :age, :integer
      end
    end

    it 'decrements specified attribute' do
      obj = document_class.new(age: 21)

      expect { obj.decrement(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.new(age: nil)

      expect { obj.decrement(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'adds specified optional value' do
      obj = document_class.new(age: 21)

      expect { obj.decrement(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'returns self' do
      obj = document_class.new(age: 21)

      expect(obj.decrement(:age)).to eql(obj)
    end

    it 'does not save changes' do
      obj = document_class.new(age: 21)
      obj.decrement(:age)

      expect(obj).to be_new_record
    end
  end

  describe '#decrement!' do
    let(:document_class) do
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

    it 'decrements specified attribute' do
      obj = document_class.create(age: 21)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.create(age: nil)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'adds specified optional value' do
      obj = document_class.create(age: 21)

      expect { obj.decrement!(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'persists the attribute new value' do
      obj = document_class.create(age: 21)
      obj.decrement!(:age, 10)
      obj_loaded = document_class.find(obj.id)

      expect(obj_loaded.age).to eq 11
    end

    it 'does not persist other changed attributes' do
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

    it 'does not restore other changed attributes persisted values' do
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
      obj = document_class.create(age: 21)
      expect(obj.decrement!(:age, 10)).to eq obj
    end

    it 'marks the attribute as not changed' do
      obj = document_class.create(age: 21)
      obj.decrement!(:age, 10)

      expect(obj.age_changed?).to eq false
    end

    it 'skips validation' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end

      obj = class_with_validation.create!(age: 20)
      obj.decrement!(:age, 7)
      expect(obj.valid?).to eq false

      obj_loaded = class_with_validation.find(obj.id)
      expect(obj_loaded.age).to eq 13
    end

    it 'skips callbacks' do
      klass = new_class do
        field :age, :integer
        field :title

        before_save :before_save_callback

        def before_save_callback; end
      end

      obj = klass.new(age: 21)

      expect(obj).to receive(:before_save_callback)
      obj.save!

      expect(obj).not_to receive(:before_save_callback)
      obj.decrement!(:age, 10)
    end

    it 'works well if there is a sort key' do
      klass_with_sort_key = new_class do
        range :name
        field :age, :integer
      end

      obj = klass_with_sort_key.create(name: 'Alex', age: 21)
      obj.decrement!(:age, 10)
      obj_loaded = klass_with_sort_key.find(obj.id, range_key: obj.name)

      expect(obj_loaded.age).to eq 11
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create(age: 21, updated_at: Time.now - 1.day)

      expect { obj.decrement!(:age) }.not_to change { document_class.find(obj.id).updated_at }
      expect { obj.decrement!(:age, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    context 'when :touch option passed' do
      it 'updates `updated_at` and the specified attributes' do
        klass = new_class do
          field :age, :integer
          field :viewed_at, :datetime
        end

        obj = klass.create(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

        expect do
          expect do
            obj.decrement!(:age, touch: [:viewed_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end

      it 'runs after_touch callback' do
        klass_with_callback = new_class do
          field :age, :integer
          after_touch { print 'run after_touch' }
        end

        obj = klass_with_callback.create

        expect { obj.decrement!(:age, touch: true) }.to output('run after_touch').to_stdout
      end
    end

    context 'when a model was concurrently deleted' do
      it 'does not persist changes when simple primary key' do
        obj = document_class.create!(age: 21)
        document_class.find(obj.id).delete

        obj.decrement!(:age)
        expect(document_class.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        obj.decrement!(:age)
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(name: 'Alex', tags: %w[a b], age: 21)
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.decrement!(:age)
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end
  end
end
