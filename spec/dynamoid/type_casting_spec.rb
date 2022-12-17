# frozen_string_literal: true

require 'spec_helper'

describe 'Type casting' do
  describe 'Boolean field' do
    let(:klass) do
      new_class do
        field :active, :boolean
      end
    end

    it 'converts nil to nil' do
      obj = klass.new(active: nil)
      expect(obj.active).to eql(nil)
    end

    it 'converts "" to nil' do
      obj = klass.new(active: '')
      expect(obj.active).to eql(nil)
    end

    it 'converts true to true' do
      obj = klass.new(active: true)
      expect(obj.active).to eql(true)
    end

    it 'converts any not empty string to true' do
      obj = klass.new(active: 'something')
      expect(obj.active).to eql(true)
    end

    it 'converts any random object to true' do
      obj = klass.new(active: [])
      expect(obj.active).to eql(true)

      obj = klass.new(active: {})
      expect(obj.active).to eql(true)

      obj = klass.new(active: :something)
      expect(obj.active).to eql(true)

      obj = klass.new(active: Object.new)
      expect(obj.active).to eql(true)

      obj = klass.new(active: 42)
      expect(obj.active).to eql(true)
    end

    it 'converts false to false' do
      obj = klass.new(active: false)
      expect(obj.active).to eql(false)
    end

    it 'converts 0 to false' do
      obj = klass.new(active: 0)
      expect(obj.active).to eql(false)
    end

    it 'converts "0" to false' do
      obj = klass.new(active: '0')
      expect(obj.active).to eql(false)
    end

    it 'converts "f" to false' do
      obj = klass.new(active: 'f')
      expect(obj.active).to eql(false)
    end

    it 'converts "F" to false' do
      obj = klass.new(active: 'F')
      expect(obj.active).to eql(false)
    end

    it 'converts "false" to false' do
      obj = klass.new(active: 'false')
      expect(obj.active).to eql(false)
    end

    it 'converts "FALSE" to false' do
      obj = klass.new(active: 'FALSE')
      expect(obj.active).to eql(false)
    end

    it 'converts "off" to false' do
      obj = klass.new(active: 'off')
      expect(obj.active).to eql(false)
    end

    it 'converts "OFF" to false' do
      obj = klass.new(active: 'OFF')
      expect(obj.active).to eql(false)
    end
  end

  describe 'DateTime field' do
    let(:klass) do
      new_class do
        field :created_at, :datetime
      end
    end

    it 'converts Date, DateTime and Time to DateTime' do
      obj = klass.new(created_at: Date.new(2018, 7, 21))
      expect(obj.created_at).to eql(DateTime.new(2018, 7, 21, 0, 0, 0, '+0'))

      datetime = DateTime.new(2018, 7, 21, 8, 40, 15, '+7')
      obj = klass.new(created_at: datetime)
      expect(obj.created_at).to eql(datetime)

      obj = klass.new(created_at: Time.new(2007, 11, 1, 15, 25, 0, '+09:00'))
      expect(obj.created_at).to eql(DateTime.new(2007, 11, 1, 15, 25, 0, '+09:00'))
    end

    it 'converts string with well formatted date or datetime to DateTime', config: { application_timezone: :utc } do
      obj = klass.new(created_at: '2018-08-21')
      expect(obj.created_at).to eql(DateTime.new(2018, 8, 21, 0, 0, 0, '+00:00'))

      obj = klass.new(created_at: '2018-08-21T21:55:30+01:00')
      expect(obj.created_at).to eql(DateTime.new(2018, 8, 21, 21, 55, 30, '+1'))
    end

    it 'preserves time zone specified in a string', config: { application_timezone: 'Hawaii' } do
      obj = klass.new(created_at: '2018-08-21T21:55:30+01:00')
      expect(obj.created_at).to eql(DateTime.new(2018, 8, 21, 21, 55, 30, '+1'))
    end

    it 'uses config.application_timezone if time zone is not specified in a string', config: { application_timezone: 'Hawaii' } do
      obj = klass.new(created_at: '2018-08-21T21:55:30')
      expect(obj.created_at).to eql(DateTime.new(2018, 8, 21, 21, 55, 30, '-10:00'))
    end

    it 'converts string with not well formatted date or datetime to nil' do
      obj = klass.new(created_at: '')
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: '  ')
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: 'abc')
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: '2018-08')
      expect(obj.created_at).to eql(nil)
    end

    it 'converts any random object to nil' do
      obj = klass.new(created_at: nil)
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: :abc)
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: [])
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: {})
      expect(obj.created_at).to eql(nil)

      obj = klass.new(created_at: true)
      expect(obj.created_at).to eql(nil)
    end
  end

  describe 'Date field' do
    let(:klass) do
      new_class do
        field :published_on, :date
      end
    end

    it 'converts Date, DateTime and Time to Date' do
      date = Date.new(2018, 7, 21)
      obj = klass.new(published_on: date)
      expect(obj.published_on).to eql(date)

      obj = klass.new(published_on: DateTime.new(2018, 7, 21, 8, 40, 15, '+7'))
      expect(obj.published_on).to eql(DateTime.new(2018, 7, 21))

      obj = klass.new(published_on: Time.new(2007, 11, 1, 15, 25, 0, '+09:00'))
      expect(obj.published_on).to eql(Date.new(2007, 11, 1))
    end

    it 'converts string with well formatted date or datetime to Date' do
      obj = klass.new(published_on: '2018-08-21')
      expect(obj.published_on).to eql(Date.new(2018, 8, 21))

      obj = klass.new(published_on: '2018-08-21T21:55:30+01:00')
      expect(obj.published_on).to eql(Date.new(2018, 8, 21))
    end

    it 'converts string with not well formatted date or datetime to nil' do
      obj = klass.new(published_on: '')
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: '  ')
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: 'abc')
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: '2018-08')
      expect(obj.published_on).to eql(nil)
    end

    it 'converts any random object to nil' do
      obj = klass.new(published_on: nil)
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: :abc)
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: [])
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: {})
      expect(obj.published_on).to eql(nil)

      obj = klass.new(published_on: true)
      expect(obj.published_on).to eql(nil)
    end
  end

  describe 'Set field' do
    let(:klass) do
      new_class do
        field :items, :set
      end
    end

    it 'converts to Set with #to_set method' do
      obj = klass.new(items: ['milk'])
      expect(obj.items).to eql(Set.new(['milk']))

      struct = Struct.new(:name, :address, :postal_code)
      obj = klass.new(items: struct.new('Joe Smith', '123 Maple, Anytown NC', 12_345))
      expect(obj.items).to eql(Set.new(['Joe Smith', '123 Maple, Anytown NC', 12_345]))
    end

    it 'converts any random object to nil' do
      obj = klass.new(items: 'a')
      expect(obj.items).to eql(nil)

      obj = klass.new(items: 13)
      expect(obj.items).to eql(nil)

      obj = klass.new(items: Time.now)
      expect(obj.items).to eql(nil)
    end

    it 'dups Set' do
      set = Set.new(['milk'])
      obj = klass.new(items: set)

      expect(obj.items).to eql(set)
      expect(obj.items).not_to equal(set)
    end

    describe 'typed set' do
      it 'type casts strings' do
        klass = new_class do
          field :values, :set, of: :string
        end

        obj = klass.new(values: Set.new([{ name: 'John' }]))

        expect(obj.values).to eql(Set.new(['{:name=>"John"}']))
      end

      it 'type casts integers' do
        klass = new_class do
          field :values, :set, of: :integer
        end

        obj = klass.new(values: Set.new([1, 1.5, '2'.to_d]))

        expect(obj.values).to eql(Set.new([1, 1, 2]))
      end

      it 'type casts numbers' do
        klass = new_class do
          field :values, :set, of: :number
        end

        obj = klass.new(values: Set.new([1, 1.5, '2'.to_d]))

        expect(obj.values).to eql(Set.new(['1'.to_d, '1.5'.to_d, '2'.to_d]))
      end

      it 'type casts dates' do
        klass = new_class do
          field :values, :set, of: :date
        end

        obj = klass.new(values: Set.new(['2018-08-21']))

        expect(obj.values).to eql(Set.new(['2018-08-21'.to_date]))
      end

      it 'type casts datetimes' do
        klass = new_class do
          field :values, :set, of: :datetime
        end

        obj = klass.new(values: Set.new(['2018-08-21T21:55:30+01:00']))

        expect(obj.values).to eql(Set.new(['2018-08-21T21:55:30+01:00'.to_datetime]))
      end

      it 'does not change serialized'
      it 'does not change custom types'
    end
  end

  describe 'Array field' do
    let(:klass) do
      new_class do
        field :items, :array
      end
    end

    it 'converts to Array with #to_a method' do
      obj = klass.new(items: Set.new(['milk']))
      expect(obj.items).to eql(['milk'])

      obj = klass.new(items: { 'milk' => 13.60 })
      expect(obj.items).to eql([['milk', 13.6]])

      struct = Struct.new(:name, :address, :postal_code)
      obj = klass.new(items: struct.new('Joe Smith', '123 Maple, Anytown NC', 12_345))
      expect(obj.items).to eql(['Joe Smith', '123 Maple, Anytown NC', 12_345])
    end

    it 'converts any random object to nil' do
      obj = klass.new(items: 'a')
      expect(obj.items).to eql(nil)

      obj = klass.new(items: 13)
      expect(obj.items).to eql(nil)

      obj = klass.new(items: Mutex.new)
      expect(obj.items).to eql(nil)
    end

    it 'dups Array' do
      array = ['milk']
      obj = klass.new(items: array)

      expect(obj.items).to eql(array)
      expect(obj.items).not_to equal(array)
    end

    describe 'typed array' do
      it 'type casts strings' do
        klass = new_class do
          field :values, :array, of: :string
        end

        obj = klass.new(values: [{ name: 'John' }])

        expect(obj.values).to eql(['{:name=>"John"}'])
      end

      it 'type casts integers' do
        klass = new_class do
          field :values, :array, of: :integer
        end

        obj = klass.new(values: [1, 1.5, '2'.to_d])

        expect(obj.values).to eql([1, 1, 2])
      end

      it 'type casts numbers' do
        klass = new_class do
          field :values, :array, of: :number
        end

        obj = klass.new(values: [1, 1.5, '2'.to_d])

        expect(obj.values).to eql(['1'.to_d, '1.5'.to_d, '2'.to_d])
      end

      it 'type casts dates' do
        klass = new_class do
          field :values, :array, of: :date
        end

        obj = klass.new(values: ['2018-08-21'])

        expect(obj.values).to eql(['2018-08-21'.to_date])
      end

      it 'type casts datetimes' do
        klass = new_class do
          field :values, :array, of: :datetime
        end

        obj = klass.new(values: ['2018-08-21T21:55:30+01:00'])

        expect(obj.values).to eql(['2018-08-21T21:55:30+01:00'.to_datetime])
      end

      it 'does not change serialized'
      it 'does not change custom types'
    end
  end

  describe 'String field' do
    let(:klass) do
      new_class do
        field :name, :string
      end
    end

    it 'converts to string with #to_s method' do
      name = double('object')
      allow(name).to receive(:to_s).and_return('string representation')
      obj = klass.new(name: name)
      expect(obj.name).to eql('string representation')

      obj = klass.new(name: 123)
      expect(obj.name).to eql('123')

      obj = klass.new(name: '2018-08-21'.to_date)
      expect(obj.name).to eql('2018-08-21')
    end

    it 'converts true to "t"' do
      obj = klass.new(name: true)
      expect(obj.name).to eql('t')
    end

    it 'converts false to "f"' do
      obj = klass.new(name: false)
      expect(obj.name).to eql('f')
    end

    it 'dups a string' do
      string = 'foo'
      obj = klass.new(name: string)

      expect(obj.name).to eql(string)
      expect(obj.name).not_to equal(string)
    end
  end

  describe 'Raw field' do
  end

  describe 'Map field' do
    let(:klass) do
      new_class do
        field :settings, :map
      end
    end

    it 'accepts Hash object' do
      obj = klass.new(settings: { foo: 21 })
      expect(obj.settings).to eq(foo: 21)
    end

    it 'tries to convert to Hash with #to_h' do
      settings = Object.new
      def settings.to_h
        { foo: 'bar' }
      end

      obj = klass.new(settings: settings)
      expect(obj.settings).to eq(foo: 'bar')

      obj = klass.new(settings: [[:foo, 'bar']])
      expect(obj.settings).to eq(foo: 'bar')
    end

    it 'tries to convert to Hash with #to_hash' do
      settings = Object.new
      def settings.to_hash
        { foo: 'bar' }
      end

      obj = klass.new(settings: settings)
      expect(obj.settings).to eq(foo: 'bar')
    end

    it 'sets nil if fails to convert to Hash' do
      obj = klass.new(settings: Object.new)
      expect(obj.settings).to eq(nil)

      obj = klass.new(settings: 'foo')
      expect(obj.settings).to eq(nil)

      obj = klass.new(settings: 42)
      expect(obj.settings).to eq(nil)
    end
  end

  describe 'Integer field' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    it 'converts to integer with #to_i method' do
      obj = klass.new(age: 23)
      expect(obj.age).to eql(23)

      obj = klass.new(age: 23.999)
      expect(obj.age).to eql(23)

      obj = klass.new(age: '1abc')
      expect(obj.age).to eql(1)

      obj = klass.new(age: '0x1a')
      expect(obj.age).to eql(0)

      obj = klass.new(age: Time.at(204_973_019))
      expect(obj.age).to eql(204_973_019)
    end

    it 'converts true to 1' do
      obj = klass.new(age: true)
      expect(obj.age).to eql(1)
    end

    it 'converts false to 0' do
      obj = klass.new(age: false)
      expect(obj.age).to eql(0)
    end

    it 'converts nil to nil' do
      obj = klass.new(age: nil)
      expect(obj.age).to eql(nil)
    end

    it 'converts "" to nil' do
      obj = klass.new(age: '')
      expect(obj.age).to eql(nil)
    end

    it 'converts string with whytespaces to nil' do
      obj = klass.new(age: ' ')
      expect(obj.age).to eql(nil)
    end

    it 'converts random object to nil' do
      obj = klass.new(age: {})
      expect(obj.age).to eql(nil)

      obj = klass.new(age: [])
      expect(obj.age).to eql(nil)

      obj = klass.new(age: Date.today)
      expect(obj.age).to eql(nil)

      obj = klass.new(age: :'26')
      expect(obj.age).to eql(nil)
    end

    it 'converts NaN and INFINITY to nil' do
      obj = klass.new(age: Float::NAN)
      expect(obj.age).to eql(nil)

      obj = klass.new(age: Float::INFINITY)
      expect(obj.age).to eql(nil)
    end
  end

  describe 'Number field' do
    let(:klass) do
      new_class do
        field :age, :number
      end
    end

    it 'converts to BigDecimal with #to_d method' do
      obj = klass.new(age: 23)
      expect(obj.age).to eql(BigDecimal('23'))

      # NOTE: 23.9 as a float becomes in JRuby 9.4.0.0:
      #       0.2389999999999999857891452847979962825775146484375e2
      # So we use a string here.
      obj = klass.new(age: "23.9")
      expect(obj.age).to eql(BigDecimal('23.9'))

      obj = klass.new(age: '23')
      expect(obj.age).to eql(BigDecimal('23'))

      obj = klass.new(age: '1abc')
      expect(obj.age).to eql(BigDecimal('1'))

      obj = klass.new(age: '0x1a')
      expect(obj.age).to eql(BigDecimal('0'))

      obj = klass.new(age: '23abc')
      expect(obj.age).to eql(BigDecimal('23'))
    end

    it 'converts symbols' do
      obj = klass.new(age: :'23')
      expect(obj.age).to eql(BigDecimal('23'))

      obj = klass.new(age: :'23abc')
      expect(obj.age).to eql(BigDecimal('23'))

      obj = klass.new(age: :abc)
      expect(obj.age).to eql(BigDecimal('0.0'))

      obj = klass.new(age: :'')
      expect(obj.age).to eql(BigDecimal('0.0'))
    end

    it 'converts true to 1' do
      obj = klass.new(age: true)
      expect(obj.age).to eql(1)
    end

    it 'converts false to 0' do
      obj = klass.new(age: false)
      expect(obj.age).to eql(0)
    end

    it 'converts nil to nil' do
      obj = klass.new(age: nil)
      expect(obj.age).to eql(nil)
    end

    it 'converts "" to nil' do
      obj = klass.new(age: '')
      expect(obj.age).to eql(nil)
    end

    it 'converts string with whytespaces to nil' do
      obj = klass.new(age: ' ')
      expect(obj.age).to eql(nil)
    end

    it 'converts random object to nil' do
      obj = klass.new(age: {})
      expect(obj.age).to eql(nil)

      obj = klass.new(age: [])
      expect(obj.age).to eql(nil)

      obj = klass.new(age: Date.today)
      expect(obj.age).to eql(nil)
    end

    it 'converts NaN and INFINITY to nil' do
      obj = klass.new(age: Float::NAN)
      expect(obj.age).to eql(nil)

      obj = klass.new(age: Float::INFINITY)
      expect(obj.age).to eql(nil)
    end
  end

  describe 'Binary field' do
    let(:klass) do
      new_class do
        field :image, :binary
      end
    end

    it 'converts to string with #to_s method' do
      value = double('object')
      allow(value).to receive(:to_s).and_return('string representation')

      obj = klass.new(image: value)
      expect(obj.image).to eql('string representation')
    end

    it 'dups a string' do
      value = 'foo'
      obj = klass.new(image: value)

      expect(obj.image).to eql(value)
      expect(obj.image).not_to equal(value)
    end
  end

  describe 'Serialized field' do
  end

  describe 'Custom type field' do
  end

  context 'there is no such field' do
    let(:klass) do
      new_class do
        attr_accessor :active
      end
    end

    it 'does not process it' do
      obj = klass.new(active: true)
      expect(obj.active).to eql(true)
    end
  end

  context 'unknown type' do
    let(:klass) do
      new_class do
        field :active, :some_incorrect_type
      end
    end

    it 'raises an exception' do
      expect do
        klass.new(active: 'f')
      end.to raise_error(ArgumentError, 'Unknown type some_incorrect_type')
    end
  end
end
