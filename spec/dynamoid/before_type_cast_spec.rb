# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Before type cast' do
  describe '#attributes_before_type_cast', config: { timestamps: false } do
    let(:klass) do
      new_class do
        field :admin, :boolean
      end
    end

    it 'returns original attributes value' do
      obj = klass.new(admin: 0)

      expect(obj.attributes_before_type_cast).to eql(
        id: nil,
        admin: 0,
        created_at: nil,
        updated_at: nil
      )
    end

    it 'returns values for all the attributes even not assigned' do
      klass_with_many_fields = new_class do
        field :first_name
        field :last_name
        field :email
      end
      obj = klass_with_many_fields.new(first_name: 'John')

      expect(obj.attributes_before_type_cast).to eql(
        id: nil,
        first_name: 'John',
        last_name: nil,
        email: nil,
        created_at: nil,
        updated_at: nil
      )
    end

    it 'returns original default value if field has default value' do
      klass_with_default_value = new_class do
        field :activated_on, :date, default: '2018-09-27'
      end
      obj = klass_with_default_value.new

      expect(obj.attributes_before_type_cast).to eql(
        id: nil,
        activated_on: '2018-09-27',
        created_at: nil,
        updated_at: nil
      )
    end

    it 'returns nil if field does not have default value' do
      obj = klass.new

      expect(obj.attributes_before_type_cast).to eql(
        id: nil,
        admin: nil,
        created_at: nil,
        updated_at: nil
      )
    end

    it 'returns values loaded from the storage before type casting' do
      obj = klass.create!(admin: false)
      obj2 = klass.find(obj.id)

      expect(obj2.attributes_before_type_cast).to eql(
        id: obj.id,
        admin: false,
        created_at: nil,
        updated_at: nil
      )
    end
  end

  describe '#read_attribute_before_type_cast' do
    let(:klass) do
      new_class do
        field :admin, :boolean
      end
    end

    it 'returns attribute original value' do
      obj = klass.new(admin: 1)

      expect(obj.read_attribute_before_type_cast(:admin)).to eql(1)
    end

    it 'accepts string as well as symbol argument' do
      obj = klass.new(admin: 1)

      expect(obj.read_attribute_before_type_cast('admin')).to eql(1)
    end

    it 'returns nil if there is no such attribute' do
      obj = klass.new

      expect(obj.read_attribute_before_type_cast(:first_name)).to eql(nil)
    end
  end

  describe '#<name>_before_type_cast' do
    let(:klass) do
      new_class do
        field :first_name
        field :last_name
        field :admin, :boolean
      end
    end

    it 'exists for every model attribute' do
      obj = klass.new

      expect(obj).to respond_to(:id)
      expect(obj).to respond_to(:first_name_before_type_cast)
      expect(obj).to respond_to(:last_name_before_type_cast)
      expect(obj).to respond_to(:admin)
      expect(obj).to respond_to(:created_at)
      expect(obj).to respond_to(:updated_at)
    end

    it 'returns attribute original value' do
      obj = klass.new(admin: 0)

      expect(obj.admin_before_type_cast).to eql(0)
    end
  end
end
