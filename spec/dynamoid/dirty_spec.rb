# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/dirty'

describe Dynamoid::Dirty do
  let(:model) do
    new_class do
      field :name
    end
  end

  describe '#changed?' do
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
      obj.name_will_change!
      expect(obj.name_change).to eq(%w[Alex Alex])
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

      it 'detects in-place change of loaded from storage model' do
        a = model.create(name: 'Alex')
        a_loaded = model.find(a.id)

        expect(a_loaded.changes).to eq({})
        a_loaded.name.upcase!
        expect(a_loaded.changes).to eq('name' => %w[Alex ALEX])
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

      it 'reports in-place change in newly instantiated model' do
        a = model.new(name: 'Alex')

        expect(a.changes).to eq('name' => [nil, 'Alex'])
        a.name.upcase!
        expect(a.changes).to eq('name' => [nil, 'ALEX'])
      end
    end

    describe '.create' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end

      it 'detects in-place change of loaded from storage model' do
        a = model.create(name: 'Alex')

        expect(a.changes).to eq({})
        a.name.upcase!
        expect(a.changes).to eq('name' => %w[Alex ALEX])
      end
    end

    describe '.update' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.update(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end

      it 'detects in-place change of updated model' do
        a = model.create(name: 'Alex')
        a_updated = model.update(a.id, name: 'Bob')

        expect(a_updated.changes).to eq({})
        a_updated.name.upcase!
        expect(a_updated.changes).to eq('name' => %w[Bob BOB])
      end
    end

    describe '.update_fields' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.update_fields(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end

      it 'detects in-place change of updated model' do
        a = model.create(name: 'Alex')
        a_updated = model.update_fields(a.id, name: 'Bob')

        expect(a_updated.changes).to eq({})
        a_updated.name.upcase!
        expect(a_updated.changes).to eq('name' => %w[Bob BOB])
      end
    end

    describe '.upsert' do
      it 'returns model without unsaved changes' do
        a = model.create(name: 'Alex')
        a_updated = model.upsert(a.id, name: 'Bob')

        expect(a_updated.changed?).to eq false
        expect(a_updated.changes).to eq({})
      end

      it 'detects in-place change of updated model' do
        a = model.create(name: 'Alex')

        a_updated = model.upsert(a.id, name: 'Bob')

        expect(a_updated.changes).to eq({})
        a_updated.name.upcase!
        expect(a_updated.changes).to eq('name' => %w[Bob BOB])
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

      it 'cleans model in-place changes' do
        a = model.create(name: 'Alex')
        a.name.upcase!

        expect(a.changes).to eq('name' => %w[Alex ALEX])
        a.reload
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

      it 'detects in-place change of updated model (Query)' do
        a = model.create(name: 'Alex')
        (a_loaded,) = model.where(id: a.id).to_a

        expect(a.changes).to eq({})
        a_loaded.name.upcase!
        expect(a_loaded.changes).to eq('name' => %w[Alex ALEX])
      end

      it 'detects in-place change of updated model (Scan)' do
        a = model.create(name: 'Alex')
        (a_loaded,) = model.where(name: a.name).to_a

        expect(a_loaded.changes).to eq({})
        a_loaded.name.upcase!
        expect(a_loaded.changes).to eq('name' => %w[Alex ALEX])
      end
    end

    describe '#save' do
      it 'cleans model unsaved changes' do
        a = model.new(name: 'Alex')
        a.save

        expect(a.changed?).to eq false
        expect(a.changes).to eq({})
      end

      it 'cleans model unsaved in-place changes' do
        a = model.new(name: 'Alex')

        a.name.upcase!
        expect(a.changes).to eq('name' => [nil, 'ALEX'])

        a.save
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

      it 'cleans model unsaved in-place changes' do
        a = model.create(name: 'Alex')

        a.name.upcase!
        expect(a.changes).to eq('name' => %w[Alex ALEX])

        a.update_attributes(name: 'Bob')
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

      it 'cleans model unsaved in-place changes' do
        a = model.create(name: 'Alex')

        a.name.upcase!
        expect(a.changes).to eq('name' => %w[Alex ALEX])

        a.update_attribute(:name, 'Bob')
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

      it 'cleans model unsaved in-place changes' do
        a = model.create(name: 'Alex')

        a.name.upcase!
        expect(a.changes).to eq('name' => %w[Alex ALEX])

        a.update do |t|
          t.set(name: 'Bob')
        end
        expect(a.changes).to eq({})
      end
    end

    describe '#touch' do
      it 'does not clean model unsaved changes' do
        a = model.create(name: 'Alex')
        a.name = 'Bob'

        expect(a.changes).to eq('name' => %w[Alex Bob])
        a.touch
        expect(a.changes).to eq('name' => %w[Alex Bob])
      end

      it 'does not clean model unsaved in-place changes' do
        a = model.create(name: 'Alex')
        a.name.upcase!

        expect(a.changes).to eq('name' => %w[Alex ALEX])
        a.touch
        expect(a.changes).to eq('name' => %w[Alex ALEX])
      end
    end
  end

  context 'in-place changes' do
    let(:klass_with_string) do
      new_class do
        field :name, :string
      end
    end

    let(:klass_with_set) do
      new_class do
        field :names, :set
      end
    end

    let(:klass_with_set_of_custom_type) do
      new_class do
        field :users, :set, of: DirtySpec::UserWithEquality
      end
    end

    let(:klass_with_array) do
      new_class do
        field :names, :array
      end
    end

    let(:klass_with_map) do
      new_class do
        field :config, :map
      end
    end

    let(:klass_with_raw) do
      new_class do
        field :metadata, :raw
      end
    end

    let(:klass_with_serialized) do
      new_class do
        field :metadata, :serialized
      end
    end

    let(:klass_with_binary) do
      new_class do
        field :image, :binary
      end
    end

    let(:klass_with_custom_type) do
      new_class do
        field :user, DirtySpec::User
      end
    end

    let(:klass_with_comparable_custom_type) do
      new_class do
        field :user, DirtySpec::UserWithEquality, comparable: true
      end
    end

    context 'string type' do
      it 'detects in-place modifying a String value' do
        obj = klass_with_string.create!(name: +'Alex')
        obj.name.upcase!

        expect(obj.changes).to eq('name' => %w[Alex ALEX])
      end
    end

    context 'set type' do
      it 'detects adding elements' do
        obj = klass_with_set.create!(names: ['Alex'])
        obj.names << 'Michael'

        expect(obj.changes).to eq('names' => [Set['Alex'], Set['Alex', 'Michael']])
      end

      it 'detects removing elements' do
        obj = klass_with_set.create!(names: %w[Alex Michael])
        obj.names.delete('Michael')

        expect(obj.changes).to eq('names' => [Set['Alex', 'Michael'], Set['Alex']])
      end

      it 'detects in-place modifying of a Set element' do
        obj = klass_with_set_of_custom_type.create!(users: [DirtySpec::UserWithEquality.new(+'Alex')])
        obj.users.map { |u| u.name.upcase! }

        expect(obj.changes).to eq(
          'users' => [
            Set[DirtySpec::UserWithEquality.new('Alex')],
            Set[DirtySpec::UserWithEquality.new('ALEX')]
          ]
        )
      end
    end

    context 'array type' do
      it 'detects adding elements' do
        obj = klass_with_array.create!(names: ['Alex'])
        obj.names << 'Michael'

        expect(obj.changes).to eq('names' => [%w[Alex], %w[Alex Michael]])
      end

      it 'detects removing elements' do
        obj = klass_with_array.create!(names: %w[Alex Michael])
        obj.names.delete('Michael')

        expect(obj.changes).to eq('names' => [%w[Alex Michael], %w[Alex]])
      end

      it 'detects in-place modifying of an Array element' do
        obj = klass_with_array.create!(names: [+'Alex'])
        obj.names.each(&:upcase!)

        expect(obj.changes).to eq('names' => [%w[Alex], %w[ALEX]])
      end
    end

    context 'map type' do
      it 'detects adding key-value pair' do
        obj = klass_with_map.create!(config: { 'level' => 'debug' })
        obj.config['namespace'] = 'us-west'

        expect(obj.changes).to eq('config' => [{ 'level' => 'debug' }, { 'level' => 'debug', 'namespace' => 'us-west' }])
      end

      it 'detects removing key-value pairs' do
        obj = klass_with_map.create!(config: { 'level' => 'debug', 'namespace' => 'us-west' })
        obj.config.delete('namespace')

        expect(obj.changes).to eq('config' => [{ 'level' => 'debug', 'namespace' => 'us-west' }, { 'level' => 'debug' }])
      end

      it 'detects in-place modifying a value of a key-value pair' do
        obj = klass_with_map.create!(config: { 'level' => +'debug' })
        obj.config['level'].upcase!

        expect(obj.changes).to eq('config' => [{ 'level' => 'debug' }, { 'level' => 'DEBUG' }])
      end
    end

    context 'raw type' do
      it 'detects structure changing' do
        obj = klass_with_raw.create!(metadata: { 'a' => 1 })
        obj.metadata['b'] = [1, 2, 3]

        expect(obj.changes).to eq('metadata' => [{ 'a' => 1 }, { 'a' => 1, 'b' => [1, 2, 3] }])
      end
    end

    context 'serialized' do
      it 'detects structure changing' do
        obj = klass_with_serialized.create!(metadata: { 'a' => 1 })
        obj.metadata['b'] = [1, 2, 3]

        expect(obj.changes).to eq('metadata' => [{ 'a' => 1 }, { 'a' => 1, 'b' => [1, 2, 3] }])
      end
    end

    context 'binary type' do
      it 'detects in-place modifying a String value' do
        obj = klass_with_binary.create!(image: '012345689'.b)
        obj.image.sub!('0123', '----')

        expect(obj.changes).to eq('image' => %w[012345689 ----45689])
      end
    end

    context 'custom type' do
      it 'detects in-place modifying' do
        obj = klass_with_custom_type.create!(user: DirtySpec::User.new(+'Alex'))
        obj.user.name.upcase!
        ScratchPad.record []

        old_value, new_value = obj.changes['user']

        expect(old_value.name).to eq 'Alex'
        expect(new_value.name).to eq 'ALEX'
        expect(ScratchPad.recorded).to eq([])
      end

      it 'detects in-place modifying when custom type is safely comparable' do
        obj = klass_with_comparable_custom_type.create!(user: DirtySpec::UserWithEquality.new(+'Alex'))
        obj.user.name.upcase!
        ScratchPad.record []

        old_value, new_value = obj.changes['user']

        expect(old_value.name).to eq 'Alex'
        expect(new_value.name).to eq 'ALEX'

        expect(ScratchPad.recorded.size).to eq(1)
        record = ScratchPad.recorded[0]

        expect(record[0]).to eq('==')
        expect(record[1]).to equal(new_value)
        expect(record[2]).to equal(old_value)
      end

      it 'reports no in-place changes when field is not modified' do
        obj = klass_with_custom_type.create!(user: DirtySpec::User.new('Alex'))

        ScratchPad.record []
        expect(obj.changes['user']).to eq(nil)
        expect(ScratchPad.recorded).to eq([])
      end

      it 'reports no in-place changes when field is not modified and custom type is safely comparable' do
        obj = klass_with_comparable_custom_type.create!(user: DirtySpec::UserWithEquality.new('Alex'))
        ScratchPad.record []

        expect(obj.changes['user']).to eq(nil)

        expect(ScratchPad.recorded.size).to eq(1)
        record = ScratchPad.recorded[0]

        expect(record[0]).to eq('==')
        expect(record[1]).to equal(obj.user)
        expect(record[2]).to eq(obj.user) # an implicit 'from-database' copy
      end
    end
  end
end
