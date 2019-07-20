# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Fields do
  let(:address) { Address.new }

  it 'declares read attributes' do
    expect(address.city).to be_nil
  end

  it 'declares write attributes' do
    address.city = 'Chicago'
    expect(address.city).to eq 'Chicago'
  end

  it 'declares a query attribute' do
  end

  it 'automatically declares id' do
    expect { address.id }.to_not raise_error
  end

  it 'allows range key serializers' do
    serializer = Class.new do
      def self.dump(val)
        val&.strftime('%m/%d/%Y')
      end

      def self.load(val)
        val && DateTime.strptime(val, '%m/%d/%Y').to_date
      end
    end

    klass = new_class do
      range :special_date, :serialized, serializer: serializer
    end

    date = '2019-02-24'.to_date
    model = klass.create!(special_date: date)
    model_loaded = klass.find(model.id, range_key: model.special_date)
    expect(model_loaded.special_date).to eq date
  end

  it 'automatically declares and fills in created_at and updated_at' do
    address.save

    address.reload
    expect(address.created_at).to be_a DateTime
    expect(address.updated_at).to be_a DateTime
  end

  context 'query attributes' do
    it 'are declared' do
      expect(address.city?).to be_falsey

      address.city = 'Chicago'

      expect(address.city?).to be_truthy
    end

    it 'return false when boolean attributes are nil or false' do
      address.deliverable = nil
      expect(address.deliverable?).to be_falsey

      address.deliverable = false
      expect(address.deliverable?).to be_falsey
    end

    it 'return true when boolean attributes are true' do
      address.deliverable = true
      expect(address.deliverable?).to be_truthy
    end
  end

  context 'with a saved address' do
    let(:address) { Address.create(deliverable: true) }
    let(:original_id) { address.id }

    it 'should write an attribute correctly' do
      address.write_attribute(:city, 'Chicago')
    end

    it 'should write an attribute with an alias' do
      address[:city] = 'Chicago'
    end

    it 'should read a written attribute' do
      address.write_attribute(:city, 'Chicago')
      expect(address.read_attribute(:city)).to eq 'Chicago'
    end

    it 'should read a written attribute with the alias' do
      address.write_attribute(:city, 'Chicago')
      expect(address[:city]).to eq 'Chicago'
    end

    it 'should update one attribute' do
      expect(address).to receive(:save).once.and_return(true)
      address.update_attribute(:city, 'Chicago')
      expect(address[:city]).to eq 'Chicago'
      expect(address.id).to eq original_id
    end

    it 'adds in dirty methods for attributes' do
      address.city = 'Chicago'
      address.save

      address.city = 'San Francisco'

      expect(address.city_was).to eq 'Chicago'
    end

    it 'returns all attributes' do
      expect(Address.attributes).to eq(id: { type: :string },
                                       created_at: { type: :datetime },
                                       updated_at: { type: :datetime },
                                       city: { type: :string },
                                       options: { type: :serialized },
                                       deliverable: { type: :boolean },
                                       latitude: { type: :number },
                                       config: { type: :raw },
                                       registered_on: { type: :date },
                                       lock_version: { type: :integer })
    end
  end

  it 'raises an exception when items size exceeds 400kb' do
    expect do
      Address.create(city: 'Ten chars ' * 500_000)
    end.to raise_error(Aws::DynamoDB::Errors::ValidationException, 'Item size has exceeded the maximum allowed size')
  end

  context '.remove_field' do
    subject { address }
    before(:each) do
      Address.field :foobar
      Address.remove_field :foobar
    end

    it 'should not be in the attributes hash' do
      expect(Address.attributes).to_not have_key(:foobar)
    end

    it 'removes the accessor' do
      expect(subject).to_not respond_to(:foobar)
    end

    it 'removes the writer' do
      expect(subject).to_not respond_to(:foobar=)
    end

    it 'removes the interrogative' do
      expect(subject).to_not respond_to(:foobar?)
    end
  end

  context 'default values for fields' do
    let(:doc_class) do
      new_class do
        field :name, :string, default: 'x'
        field :uid, :integer, default: -> { 42 }
        field :config, :serialized, default: {}
        field :version, :integer, default: 1
        field :hidden, :boolean, default: false
      end
    end

    it 'returns default value specified as object' do
      expect(doc_class.new.name).to eq('x')
    end

    it 'returns default value specified as lamda/block (callable object)' do
      expect(doc_class.new.uid).to eq(42)
    end

    it 'returns default value as is for serializable field' do
      expect(doc_class.new.config).to eq({})
    end

    it 'supports `false` as default value' do
      expect(doc_class.new.hidden).to eq(false)
    end

    it 'can modify default value independently for every instance' do
      doc = doc_class.new
      doc.name << 'y'
      expect(doc_class.new.name).to eq('x')
    end

    it 'returns default value specified as object even if value cannot be duplicated' do
      expect(doc_class.new.version).to eq(1)
    end

    it 'should save default values' do
      doc = doc_class.create!
      doc = doc_class.find(doc.id)
      expect(doc.name).to eq('x')
      expect(doc.uid).to eq(42)
      expect(doc.config).to eq({})
      expect(doc.version).to eq(1)
      expect(doc.hidden).to be false
    end

    it 'does not use default value if nil value assigns explicitly' do
      doc = doc_class.new(name: nil)
      expect(doc.name).to eq nil
    end

    it 'supports default value for custom type' do
      user_class = Class.new do
        attr_accessor :name

        def initialize(name)
          self.name = name
        end

        def dynamoid_dump
          name
        end

        def eql?(other)
          name == other.name
        end

        def hash
          name.hash
        end

        def self.dynamoid_load(string)
          new(string.to_s)
        end
      end

      model_class = new_class(user: user_class.new('Mary')) do |options|
        field :user, user_class, default: options[:user]
      end

      model = model_class.create
      model = model_class.find(model.id)

      expect(model.user).to eql user_class.new('Mary')
    end
  end

  describe 'deprecated :float field type' do
    let(:doc) do
      new_class do
        field :distance_m, :float
      end.new
    end

    it 'acts as a :number field' do
      doc.distance_m = 5.33
      doc.save!
      doc.reload
      expect(doc.distance_m).to eq 5.33
    end

    it 'warns' do
      expect(Dynamoid.logger).to receive(:warn).with(/deprecated/)
      doc
    end
  end

  context 'extention overrides field accessors' do
    let(:klass) do
      extention = Module.new do
        def name
          super.upcase
        end

        def name=(str)
          super(str.try(:downcase))
        end
      end

      new_class do
        include extention

        field :name
      end
    end

    it 'can access new setter' do
      address = klass.new
      address.name = 'AB cd'
      expect(address[:name]).to eq('ab cd')
    end

    it 'can access new getter' do
      address = klass.new
      address.name = 'ABcd'
      expect(address.name).to eq('ABCD')
    end
  end

  describe '#write_attribute' do
    describe 'type casting' do
      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.new
        obj.write_attribute(:count, '101')
        expect(obj.attributes[:count]).to eql(101)
      end
    end
  end
end
