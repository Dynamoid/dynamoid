require 'spec_helper'

RSpec.describe 'STI' do
  describe 'fields' do
    let!(:class_a) do
      new_class do
        field :type
        field :a
      end
    end

    let!(:class_b) do
      Class.new(class_a) do
        field :b
      end
    end

    let!(:class_c) do
      Class.new(class_a) do
        field :c
      end
    end

    it 'enables only own attributes in a base class ' do
      expect(class_a.attributes.keys).to match_array(%i[id type a created_at updated_at])
    end

    it 'enabled only own attributes and inherited in a child class' do
      expect(class_b.attributes.keys).to include(:a)
      expect(class_b.attributes.keys).to include(:b)
      expect(class_b.attributes.keys).not_to include(:c)
    end
  end

  describe 'document' do
    it 'fills `type` field with class name' do
      expect(Vehicle.new.type).to eq 'Vehicle'
    end

    it 'reports the same table name for both base and derived classes' do
      expect(Vehicle.table_name).to eq Car.table_name
      expect(Vehicle.table_name).to eq NuclearSubmarine.table_name
    end
  end

  describe 'persistence' do
    before do
      A = new_class class_name: 'A' do
        field :type
      end
      B = Class.new(A) do
        def self.name; 'B'; end
      end
      C = Class.new(A) do
        def self.name; 'C'; end
      end
      D = Class.new(B) do
        def self.name; 'D'; end
      end
    end

    after do
      Object.send(:remove_const, :A)
      Object.send(:remove_const, :B)
      Object.send(:remove_const, :C)
      Object.send(:remove_const, :D)
    end

    it 'saves subclass objects in the parent table' do
      b = B.create
      expect(A.find(b.id)).to eql b
    end

    it 'loads subclass item when querying the parent table' do
      b = B.create!
      c = C.create!
      d = D.create!

      expect(A.all.to_a).to contain_exactly(b, c, d)
    end

    it 'does not load parent item when quering the child table' do
      a = A.create!
      b = B.create!

      expect(B.all.to_a).to eql([b])
    end

    it 'does not load items of sibling class' do
      b = B.create!
      c = C.create!

      expect(B.all.to_a).to eql([b])
      expect(C.all.to_a).to eql([c])
    end
  end

  describe 'quering' do
    describe 'where' do
      it 'honors STI' do
        Vehicle.create(description: 'Description')
        car = Car.create(description: 'Description')

        expect(Car.where(description: 'Description').all.to_a).to eq [car]
      end
    end

    describe 'all' do
      it 'honors STI' do
        Vehicle.create(description: 'Description')
        car = Car.create

        expect(Car.all.to_a).to eq [car]
      end
    end
  end
end
