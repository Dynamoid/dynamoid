# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Dirty do
  let(:model) do
    new_class do
      field :name
    end
  end

  describe '#changed?' do
    it 'works' do
      obj = model.new(name: 'Bob')
      expect(obj.name_changed?).to eq true
    end

    it 'returns true if any of the attributes have unsaved changes' do
      obj = model.new(name: 'Bob')
      expect(obj.changed?).to eq true

      obj = model.create(name: 'Bob')
      obj.name = 'Alex'
      expect(obj.changed?).to eq true
    end

    it 'returns false otherwise' do
      obj = model.create(name: 'Bob')
      expect(obj.changed?).to eq false

      obj = model.new
      expect(obj.changed?).to eq false

      obj = model.create(name: 'Bob')
      obj.name = 'Bob'
      expect(obj.changed?).to eq false
    end
  end

  describe '#changed' do
    it 'returns an array with the name of the attributes with unsaved changes' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.changed).to eq ['name']

      obj = model.new(name: 'Alex')
      expect(obj.changed).to eq ['name']
    end

    it 'returns [] when there are no unsaved changes' do
      obj = model.create(name: 'Alex')
      expect(obj.changed).to eq []

      obj = model.new
      expect(obj.changed).to eq []

      obj = model.create(name: 'Alex')
      obj.name = 'Alex'
      expect(obj.changed).to eq []
    end
  end

  describe '#changed_attributes' do
    it 'returns a hash of the attributes with unsaved changes indicating their original values' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.changed_attributes).to eq('name' => 'Alex')

      obj = model.new(name: 'Alex')
      expect(obj.changed_attributes).to eq('name' => nil)
    end

    it 'returns {} when there are no unsaved changes' do
      obj = model.create(name: 'Alex')
      expect(obj.changed_attributes).to eq({})

      obj = model.new
      expect(obj.changed_attributes).to eq({})

      obj = model.create(name: 'Alex')
      obj.name = 'Alex'
      expect(obj.changed_attributes).to eq({})
    end
  end

  describe '#clear_changes_information' do
    it 'clears current changes information' do
      obj = model.new(name: 'Alex')

      expect do
        obj.clear_changes_information
      end.to change { obj.changes }.from(a_hash_including(name: [nil, 'Alex'])).to({})
    end

    it 'clears previous changes information' do
      obj = model.create!(name: 'Alex') # previous change
      obj.name = 'Michael' # current change

      expect do
        obj.clear_changes_information
      end.to change { obj.previous_changes }.from(a_hash_including(name: [nil, 'Alex'])).to({})
    end
  end

  describe '#changes_applied' do
    it 'clears current changes information' do
      obj = model.new(name: 'Alex')

      expect do
        obj.changes_applied
      end.to change { obj.changes }.from(name: [nil, 'Alex']).to({})
    end

    it 'moves changes to previous changes' do
      obj = model.new(name: 'Alex')

      expect do
        obj.changes_applied
      end.to change { obj.previous_changes }.from({}).to(name: [nil, 'Alex'])
    end
  end

  describe '#clear_attribute_changes' do
    it 'removes changes information for specified attributes' do
      klass_with_several_fields = new_class do
        field :name
        field :age, :integer
        field :city
      end

      obj = klass_with_several_fields.create!(name: 'Alex', age: 21, city: 'Ottawa')
      obj.name = 'Michael'
      obj.age = 36
      obj.city = 'Mexico'

      expect(obj.changes).to eql('name' => %w[Alex Michael], 'age' => [21, 36], 'city' => %w[Ottawa Mexico])
      expect(obj.changed_attributes).to eql('name' => 'Alex', 'age' => 21, 'city' => 'Ottawa')
      expect(obj.name_changed?).to eql true
      expect(obj.age_changed?).to eql true
      expect(obj.city_changed?).to eql true

      obj.clear_attribute_changes(%w[name age])

      expect(obj.changes).to eql('city' => %w[Ottawa Mexico])
      expect(obj.changed_attributes).to eql('city' => 'Ottawa')
      expect(obj.name_changed?).to eql false
      expect(obj.age_changed?).to eql false
      expect(obj.city_changed?).to eql true
    end
  end

  describe '#changes' do
    it 'returns a hash of changed attributes indicating their original and new values' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.changes).to eq('name' => %w[Alex Bob])

      obj = model.new(name: 'Alex')
      expect(obj.changes).to eq('name' => [nil, 'Alex'])
    end

    it 'returns {} when there are no unsaved changes' do
      obj = model.create(name: 'Alex')
      expect(obj.changes).to eq({})

      obj = model.new
      expect(obj.changes).to eq({})

      obj = model.create(name: 'Alex')
      obj.name = 'Alex'
      expect(obj.changes).to eq({})
    end
  end

  describe '#previous_changes' do
    it 'returns a hash of attributes that were changed before the model was saved' do
      obj = model.create(name: 'Alex', updated_at: '2019-07-20 00:53:32'.to_datetime)
      obj.name = 'Bob'
      obj.updated_at = '2019-07-20 20:11:01'.to_datetime
      obj.save

      expect(obj.previous_changes).to eq(
        'name' => %w[Alex Bob],
        'updated_at' => ['2019-07-20 00:53:32'.to_datetime, '2019-07-20 20:11:01'.to_datetime]
      )

      obj = model.create(name: 'Alex')
      # there are also changes for `created_at` and `updated_at` - just don't check them
      expect(obj.previous_changes).to include('id' => [nil, obj.id], 'name' => [nil, 'Alex'])
    end

    it 'returns {} when there were no changes made before saving' do
      obj = model.create(name: 'Alex')
      obj = model.find(obj.id)
      expect(obj.previous_changes).to eq({})

      obj = model.new(name: 'Alex')
      expect(obj.previous_changes).to eq({})
    end
  end

  describe '#<attribute>_changed?' do
    it 'returns true if attribute has unsaved value' do
      obj = model.new(name: 'Bob')
      expect(obj.name_changed?).to eq true

      obj = model.create(name: 'Bob')
      obj.name = 'Alex'
      expect(obj.name_changed?).to eq true
    end

    it 'returns false/nil otherwise' do
      obj = model.create(name: 'Bob')
      expect(obj.name_changed?).to eq false

      obj = model.new
      expect(obj.name_changed?).to eq false # in Rails => nil

      obj = model.create(name: 'Bob')
      obj.name = 'Bob'
      expect(obj.name_changed?).to eq false
    end
  end

  describe '#<attribute>_change' do
    it 'returns an array with previous and current values' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.name_change).to eq(%w[Alex Bob])

      obj = model.new(name: 'Alex')
      expect(obj.name_change).to eq([nil, 'Alex'])
    end

    it 'returns nil when attribute does not have unsaved value' do
      obj = model.create(name: 'Alex')
      expect(obj.name_change).to eq(nil)

      obj = model.new
      expect(obj.name_change).to eq(nil)

      obj = model.create(name: 'Alex')
      obj.name = 'Alex'
      expect(obj.name_change).to eq(nil)
    end
  end

  describe '#<attribute>_previously_changed?' do
    it 'returns true if attribute was changed before model was saved' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      obj.save
      expect(obj.name_previously_changed?).to eq(true)

      obj = model.create(name: 'Alex')
      expect(obj.name_previously_changed?).to eq(true)
    end

    it 'returns false otherwise' do
      obj = model.create(name: 'Alex')
      obj = model.find(obj.id)
      expect(obj.name_previously_changed?).to eq(false)

      obj = model.new(name: 'Alex')
      expect(obj.name_previously_changed?).to eq(false)
    end
  end

  describe '#<attribute>_previous_change' do
    it 'returns an array of old and changed attribute value before the model was saved' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      obj.save
      expect(obj.name_previous_change).to eq(%w[Alex Bob])

      obj = model.create(name: 'Alex')
      expect(obj.name_previous_change).to eq([nil, 'Alex'])
    end

    it 'returns nil when there were no changes made before saving' do
      obj = model.create(name: 'Alex')
      obj = model.find(obj.id)
      expect(obj.name_previous_change).to eq(nil)

      obj = model.new(name: 'Alex')
      expect(obj.name_previous_change).to eq(nil)
    end
  end

  describe '#<attribute>_will_change!' do
    it 'marks that the attribute is changing' do
      obj = model.create(name: 'Alex')
      obj.name_will_change!
      obj.name.reverse!
      expect(obj.name_change).to eq(%w[Alex xelA])

      obj = model.create(name: 'Alex')
      obj.name.reverse!
      expect(obj.name_change).to eq(nil)
    end
  end

  describe '#<attribute>_was' do
    it 'returns saved attribute value before changing' do
      obj = model.create(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.name_was).to eq('Alex')

      obj = model.new(name: 'Alex')
      obj.name = 'Bob'
      expect(obj.name_was).to eq(nil)
    end

    it 'returns current saved value if attribute was not changed' do
      obj = model.create(name: 'Alex')
      expect(obj.name_was).to eq('Alex')
    end
  end

  describe '#restore_<attribute>!' do
    it 'restores original value if attribute is changed' do
      a = model.create(name: 'Alex')
      a.name = 'Bob'
      a.restore_name!
      expect(a.name).to eq 'Alex'
    end

    it 'removes changes information' do
      a = model.create(name: 'Alex')
      a.name = 'Bob'

      expect { a.restore_name! }.to change { a.changed? }.from(true).to(false)
    end

    it 'returns saved value otherwise' do
      a = model.new(name: 'Alex')
      a.restore_name!
      expect(a.name).to eq nil

      a = model.create(name: 'Alex')
      a.restore_name!
      expect(a.name).to eq 'Alex'
    end
  end

  describe 'Document methods and dirty changes' do
    describe '.find' do
      it 'loads model that does not have unsaved changes' do
        a = model.create(name: 'Alex')
        a_loaded = model.find(a.id)

        expect(a_loaded.changed?).to eq false
        expect(a_loaded.changes).to eq({})
      end

      it 'loads several models that do not have unsaved changes' do
        a = model.create(name: 'Alex')
        b = model.create(name: 'Bob')
        (a_loaded, b_loaded) = model.find(a.id, b.id)

        expect(a_loaded.changed?).to eq false
        expect(a_loaded.changes).to eq({})

        expect(b_loaded.changed?).to eq false
        expect(b_loaded.changes).to eq({})
      end
    end

    describe '.new' do
      it 'returns model that does not have unsaved changes if called without arguments' do
        a = model.new

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end

      it 'returns model that does have unsaved changes if called with arguments' do
        a = model.new(name: 'Alex')

        expect(a.changed?).to eq true
        expect(a.changes).to eq('name' => [nil, 'Alex'])
      end
    end

    describe '.create' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '.update' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.update(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end
    end

    describe '.update_fields' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.update_fields(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end
    end

    describe '.upsert' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.upsert(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end
    end

    describe '#reload' do
      it 'cleans model unsaved changes' do
        a = model.create(name: 'Alex')
        a.name = 'Bob'
        a.reload

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '.where' do
      it 'returns model without unsaved changes (Query)' do
        a = model.create(name: 'Alex')
        (a_loaded,) = model.where(id: a.id).to_a

        expect(a_loaded.changed?).to eq false
        expect(a_loaded.changes).to eq({})
      end

      it 'returns model without unsaved changes (Scan)' do
        a = model.create(name: 'Alex')
        (a_loaded,) = model.where(name: a.name).to_a

        expect(a_loaded.changed?).to eq false
        expect(a_loaded.changes).to eq({})
      end
    end

    describe '#save' do
      it 'cleans model unsaved changes' do
        a = model.new(name: 'Alex')
        a.save

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '#update_attributes' do
      it 'cleans model unsaved changes' do
        a = model.create(name: 'Alex')
        a.update_attributes(name: 'Bob')

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '#update_attribute' do
      it 'cleans model unsaved changes' do
        a = model.create(name: 'Alex')
        a.update_attribute(:name, 'Bob')

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '#update' do
      it 'cleans model unsaved changes' do
        a = model.create(name: 'Alex')
        a.update do |t|
          t.set(name: 'Bob')
        end

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end

    describe '#touch' do
      it 'cleans model unsaved changes' do
        a = model.create(name: 'Alex')
        a.touch

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end
    end
  end
end
