# frozen_string_literal: true

require 'spec_helper'

describe 'Type casting' do
  describe 'Boolean field' do
    let(:klass) do
      new_class do
        field :active, :boolean
      end
    end

    it "converts 'f' to false" do
      obj = klass.new(active: 'f')
      expect(obj.attributes[:active]).to eql(false)
    end

    it "converts 't' true true" do
      obj = klass.new(active: 't')
      expect(obj.attributes[:active]).to eql(true)
    end

    it "converts 'false' to false" do
      obj = klass.new(active: 'false')
      expect(obj.attributes[:active]).to eql(false)
    end

    it "converts 'true' true true" do
      obj = klass.new(active: 'true')
      expect(obj.attributes[:active]).to eql(true)
    end
  end

  describe 'DateTime field' do
  end

  describe 'Date field' do
  end

  describe 'Set field' do
    let(:klass) do
      new_class do
        field :items, :set
      end
    end

    it 'converts Enumerable to Set' do
      obj = klass.new(items: ['milk'])
      expect(obj.attributes[:items]).to eq(Set.new(['milk']))

      struct = Struct.new(:name, :address, :zip)
      obj = klass.new(items: struct.new('Joe Smith', '123 Maple, Anytown NC', 12_345))
      expect(obj.attributes[:items]).to eq(Set.new(['Joe Smith', '123 Maple, Anytown NC', 12_345]))
    end
  end

  describe 'Array field' do
    let(:klass) do
      new_class do
        field :items, :array
      end
    end

    it 'converts to array with #to_a method' do
      obj = klass.new(items: Set.new(['milk']))
      expect(obj.attributes[:items]).to eq(['milk'])

      obj = klass.new(items: { 'milk' => 13.60 })
      expect(obj.attributes[:items]).to eq([['milk', 13.6]])

      struct = Struct.new(:name, :address, :zip)
      obj = klass.new(items: struct.new('Joe Smith', '123 Maple, Anytown NC', 12_345))
      expect(obj.attributes[:items]).to eq(['Joe Smith', '123 Maple, Anytown NC', 12_345])
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
      expect(obj.attributes[:name]).to eql('string representation')
    end
  end

  describe 'Raw field' do
  end

  describe 'Integer field' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    it 'converts to integer with Integer() method' do
      obj = klass.new(age: 23.999)
      expect(obj.attributes[:age]).to eq(23)

      obj = klass.new(age: '0x1a')
      expect(obj.attributes[:age]).to eq(26)

      obj = klass.new(age: Time.at(204_973_019))
      expect(obj.attributes[:age]).to eq(204_973_019)

      expect { klass.new(age: 'abc') }.to raise_error(ArgumentError, /invalid value for Integer/)
      expect { klass.new(age: '0 abc') }.to raise_error(ArgumentError, /invalid value for Integer/)
    end
  end

  describe 'Number field' do
    let(:klass) do
      new_class do
        field :age, :number
      end
    end

    it 'converts to BigDecimal with BigDecimal() method' do
      obj = klass.new(age: 23)
      expect(obj.attributes[:age]).to eq(BigDecimal('23'))

      obj = klass.new(age: 23.9)
      expect(obj.attributes[:age]).to eq(BigDecimal('23.9'))

      obj = klass.new(age: '23')
      expect(obj.attributes[:age]).to eq(BigDecimal('23'))

      obj = klass.new(age: '0x1a')
      expect(obj.attributes[:age]).to eq(BigDecimal('0'))

      obj = klass.new(age: '23abc')
      expect(obj.attributes[:age]).to eq(BigDecimal('23'))
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
