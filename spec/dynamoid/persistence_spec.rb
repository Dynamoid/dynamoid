# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

describe Dynamoid::Persistence do
  describe 'class methods' do
    it 'supports .table_name' do
      klass = new_class
      expect(klass.table_name).to be_present
    end

    it 'supports .create_table' do
      klass = new_class
      klass.create_table
      expect(Dynamoid.adapter.list_tables).to include(klass.table_name)
    end

    it 'supports .delete_table' do
      klass = new_class
      klass.create_table
      expect(Dynamoid.adapter.list_tables).to include(klass.table_name)
      klass.delete_table
      expect(Dynamoid.adapter.list_tables).not_to include(klass.table_name)
    end

    it 'supports .import' do
      klass = new_class do
        field :name
      end
      klass.create_table
      instances = klass.import([{ name: 'Alex' }, { name: 'Bob' }])
      expect(instances.size).to eq 2
      expect(klass.all.to_a).to match_array(instances)
    end

    it 'supports .create' do
      klass = new_class do
        field :name
      end
      instance = klass.create(name: 'Alex')
      expect(instance.persisted?).to eq true
      expect(instance.name).to eq 'Alex'
    end

    it 'supports .create!' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.persisted?).to eq true
      expect(instance.name).to eq 'Alex'
    end

    it 'supports .update' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      updated = klass.update(instance.id, name: 'Bob')
      expect(updated.name).to eq 'Bob'
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports .update!' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      updated = klass.update!(instance.id, name: 'Bob')
      expect(updated.name).to eq 'Bob'
    end

    it 'supports .update_fields' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      updated = klass.update_fields(instance.id, name: 'Bob')
      expect(updated.name).to eq 'Bob'
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports .upsert' do
      klass = new_class do
        field :name
      end
      klass.create_table
      instance = klass.upsert('123', name: 'Alex')
      expect(instance.id).to eq '123'
      expect(instance.name).to eq 'Alex'
      expect(klass.find('123').name).to eq 'Alex'
    end

    it 'supports .inc' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 10)
      klass.inc(instance.id, age: 5)
      expect(klass.find(instance.id).age).to eq 15
    end

    it 'supports .delete' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(klass.find(instance.id)).to be_present
      klass.delete(instance.id)
      expect { klass.find(instance.id) }.to raise_error(Dynamoid::Errors::RecordNotFound)
    end
  end

  describe 'instance methods' do
    it 'supports #touch' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')

      old_updated_at = instance.updated_at
      sleep 0.1
      instance.touch
      expect(instance.updated_at).to be > old_updated_at
      expect(klass.find(instance.id).updated_at).to be > old_updated_at
    end

    it 'supports #persisted?' do
      klass = new_class
      instance = klass.new
      expect(instance.persisted?).to eq false
      instance.save
      expect(instance.persisted?).to eq true
      instance.delete
      expect(instance.persisted?).to eq false
    end

    it 'supports #save' do
      klass = new_class do
        field :name
      end
      instance = klass.new(name: 'Alex')
      expect(instance.save).to be_truthy
      expect(klass.find(instance.id).name).to eq 'Alex'
    end

    it 'supports #save!' do
      klass = new_class do
        field :name
        validates :name, presence: true
      end
      instance = klass.new(name: 'Alex')
      expect(instance.save!).to eq instance
      expect(klass.find(instance.id).name).to eq 'Alex'
    end

    it 'supports #update_attributes' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.update_attributes(name: 'Bob')).to be_truthy
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports #update_attributes!' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.update_attributes!(name: 'Bob')).to be_truthy
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports #update_attribute' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      instance.update_attribute(:name, 'Bob')
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports #update_attribute!' do
      klass = new_class do
        field :name
        validates :name, presence: true
      end
      instance = klass.create!(name: 'Alex')
      instance.update_attribute!(:name, 'Bob')
      expect(klass.find(instance.id).name).to eq 'Bob'
    end

    it 'supports #update!' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 20)
      instance.update! do |t|
        t.add(age: 5)
      end
      expect(instance.age).to eq 25
      expect(klass.find(instance.id).age).to eq 25
    end

    it 'supports #update' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 20)
      expect(instance.update { |t| t.set(age: 30) }).to eq true
      expect(instance.age).to eq 30
      expect(klass.find(instance.id).age).to eq 30
    end

    it 'supports #increment' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 10)

      instance.increment(:age, 3)
      expect(instance.age).to eq 13
      expect(klass.find(instance.id).age).to eq 10
    end

    it 'supports #increment!' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 10)

      instance.increment!(:age, 2)
      expect(instance.age).to eq 12
      expect(klass.find(instance.id).age).to eq 12
    end

    it 'supports #decrement' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 10)

      instance.decrement(:age, 3)
      expect(instance.age).to eq 7
      expect(klass.find(instance.id).age).to eq 10
    end

    it 'supports #decrement!' do
      klass = new_class do
        field :age, :integer
      end
      instance = klass.create!(age: 10)

      instance.decrement!(:age, 2)
      expect(instance.age).to eq 8
      expect(klass.find(instance.id).age).to eq 8
    end

    it 'supports #destroy' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.destroy).to eq instance
      expect { klass.find(instance.id) }.to raise_error(Dynamoid::Errors::RecordNotFound)
    end

    it 'supports #destroy!' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.destroy!).to eq instance
      expect { klass.find(instance.id) }.to raise_error(Dynamoid::Errors::RecordNotFound)
    end

    it 'supports #delete' do
      klass = new_class do
        field :name
      end
      instance = klass.create!(name: 'Alex')
      expect(instance.delete).to eq instance
      expect { klass.find(instance.id) }.to raise_error(Dynamoid::Errors::RecordNotFound)
    end
  end
end
