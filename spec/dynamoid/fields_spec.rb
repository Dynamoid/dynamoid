# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/fields'

describe Dynamoid::Fields do
  let(:address) { Address.new }

  describe '.table' do
    it 'follows any table options provided to it' do
      tweet = Tweet.create(group: 12_345)

      expect { tweet.id }.to raise_error(NoMethodError)
      expect(tweet.tweet_id).not_to be_nil
      expect(Tweet.table_name).to eq 'dynamoid_tests_twitters'
      expect(Tweet.hash_key).to eq :tweet_id
      expect(Tweet.read_capacity).to eq 200
      expect(Tweet.write_capacity).to eq 200
    end

    it 'has default table options' do
      address = Address.create

      expect(address.id).not_to be_nil
      expect(Address.table_name).to eq 'dynamoid_tests_addresses'
      expect(Address.hash_key).to eq :id
      expect(Address.read_capacity).to eq 100
      expect(Address.write_capacity).to eq 20
      expect(Address.inheritance_field).to eq :type
    end

    describe 'TTL (Time to Live)' do
      let(:model) do
        new_class do
          table expires: { field: :expired_at, after: 30 * 60 }

          field :expired_at, :integer
        end
      end

      let(:model_with_wrong_field_name) do
        new_class do
          table expires: { field: :foo, after: 30 * 60 }

          field :expired_at, :integer
        end
      end

      it 'sets default value at the creation' do
        travel 1.hour do
          obj = model.create
          expect(obj.expired_at).to eq(Time.now.to_i + (30 * 60))
        end
      end

      it 'sets default value at the updating' do
        obj = model.create

        travel 1.hour do
          obj.update_attributes(expired_at: nil)
          expect(obj.expired_at).to eq(Time.now.to_i + (30 * 60))
        end
      end

      it 'does not override already existing value' do
        obj = model.create(expired_at: 1024)
        expect(obj.expired_at).to eq 1024

        obj.update_attributes(expired_at: 512)
        expect(obj.expired_at).to eq 512
      end

      it 'raises an error if specified wrong field name' do
        # error messages may very on different Ruby versions and use either ` or '.
        expect do
          model_with_wrong_field_name.create
        end.to raise_error(NoMethodError, /undefined method (`|')foo='/)
      end
    end

    context 'when :key and :key_type options specified' do
      it 'changes a hash key attribute declared type' do
        klass = new_class do
          table key: :hash_key, key_type: :integer
        end

        expect(klass.attributes[:hash_key][:type]).to eq(:integer)
      end

      it 'changes a hash key attribute actual type' do
        klass = new_class do
          table key: :hash_key, key_type: :integer
          field :name
        end

        klass.create!(hash_key: 42, name: 'Alex')
        obj = klass.find(42)
        expect(obj.name).to eq 'Alex'
      end
    end
  end

  describe '.field' do
    it 'declares a read method' do
      expect(address.city).to be_nil
    end

    it 'declares a write method' do
      address.city = 'Chicago'
      expect(address.city).to eq 'Chicago'
    end

    it 'declares a predicate method' do
      expect(address).not_to be_city
      address.city = 'Chicago'
      expect(address).to be_city
    end

    describe 'write methods' do
      it 'allow interception of #write_attribute on load' do
        klass = new_class do
          field :city

          def city=(value)
            self[:city] = value.downcase
          end
        end
        expect(klass.new(city: 'Chicago').city).to eq 'chicago'
      end
    end

    describe 'predicate methods' do
      it 'return false when boolean attributes are nil or false' do
        address.deliverable = nil
        expect(address).not_to be_deliverable

        address.deliverable = false
        expect(address).not_to be_deliverable
      end

      it 'return true when boolean attributes are true' do
        address.deliverable = true
        expect(address).to be_deliverable
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

      it 'saves default values' do
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
        model_class = new_class do
          field :user, FieldsSpecs::User, default: FieldsSpecs::User.new('Mary')
        end

        model = model_class.create
        model = model_class.find(model.id)

        expect(model.user).to eql FieldsSpecs::User.new('Mary')
      end
    end

    context 'when :alias option specified' do
      let(:klass) do
        new_class do
          field :Name, :string, alias: :name
        end
      end

      it 'generates getter and setter for alias' do
        object = klass.new

        object.Name = 'Alex'
        expect(object.name).to eq('Alex')

        object.name = 'Michael'
        expect(object.name).to eq('Michael')
      end

      it 'generates <name>? method' do
        object = klass.new

        expect(object.name?).to eq false
        object.name = 'Alex'
        expect(object.name?).to eq true
      end

      it 'generates <name>_before_type_cast method' do
        object = klass.new(name: :Alex)

        expect(object.name).to eq 'Alex'
        expect(object.name_before_type_cast).to eq :Alex
      end
    end

    context 'an extention overrides field accessors' do
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

    context 'when new generated method overrides existing one' do
      let(:module_with_methods) do
        Module.new do
          def foo; end

          def bar=; end

          def baz?; end

          def foobar_before_type_cast?; end
        end
      end

      it 'warns about getter' do
        message = 'Method foo generated for the field foo overrides already existing method'
        expect(Dynamoid.logger).to receive(:warn).with(message)

        new_class(module: module_with_methods, class_name: 'Foobar') do
          include @helper_options[:module]
          field :foo
        end
      end

      it 'warns about setter' do
        message = 'Method bar= generated for the field bar overrides already existing method'
        expect(Dynamoid.logger).to receive(:warn).with(message)

        new_class(module: module_with_methods) do
          include @helper_options[:module]
          field :bar
        end
      end

      it 'warns about <name>?' do
        message = 'Method baz? generated for the field baz overrides already existing method'
        expect(Dynamoid.logger).to receive(:warn).with(message)

        new_class(module: module_with_methods) do
          include @helper_options[:module]
          field :baz
        end
      end

      it 'warns about <name>_before_type_cast' do
        message = 'Method foobar_before_type_cast? generated for the field foobar overrides already existing method'
        expect(Dynamoid.logger).to receive(:warn).with(message)

        new_class(module: module_with_methods) do
          include @helper_options[:module]
          field :foobar
        end
      end

      it 'warns about hash_key field' do
        messages = [
          'Method hash_key= generated for the field hash_key overrides already existing method',
          'Method hash_key generated for the field hash_key overrides already existing method'
        ]
        expect(Dynamoid.logger).to receive(:warn).with(messages[0])
        expect(Dynamoid.logger).to receive(:warn).with(messages[1])

        new_class do
          table key: :hash_key
        end
      end

      it 'warns about range_value field' do
        messages = [
          'Method range_value= generated for the field range_value overrides already existing method',
          'Method range_value generated for the field range_value overrides already existing method'
        ]
        expect(Dynamoid.logger).to receive(:warn).with(messages[0])
        expect(Dynamoid.logger).to receive(:warn).with(messages[1])

        new_class do
          range :range_value
        end
      end
    end

    describe 'deprecated :float field type' do
      let(:doc) do
        new_class do
          field :distance_m, :float
        end.new
      end

      it 'acts as a :number field' do
        # NOTE: Set as string to avoid error on JRuby 9.4.0.0:
        #         Aws::DynamoDB::Errors::ValidationException:
        #           DynamoDB only supports precision up to 38 digits
        doc.distance_m = '5.33'
        doc.save!
        doc.reload
        expect(doc.distance_m).to eq 5.33
      end

      it 'warns' do
        expect(Dynamoid.logger).to receive(:warn).with(/deprecated/)
        doc
      end
    end
  end

  describe '.range' do
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
  end

  describe '.remove_field' do
    subject { address }

    before do
      Address.field :foobar
      Address.remove_field :foobar
    end

    it 'is not in the attributes hash' do
      expect(Address.attributes).not_to have_key(:foobar)
    end

    it 'removes the accessor' do
      expect(subject).not_to respond_to(:foobar)
    end

    it 'removes the writer' do
      expect(subject).not_to respond_to(:foobar=)
    end

    it 'removes the interrogative' do
      expect(subject).not_to respond_to(:foobar?)
    end
  end

  describe '.attributes' do
    it 'returns all attributes' do
      expect(Address.attributes).to eq(id: { type: :string },
                                       created_at: { type: :datetime },
                                       updated_at: { type: :datetime },
                                       city: { alias: :CityName, type: :string },
                                       options: { type: :serialized },
                                       deliverable: { type: :boolean },
                                       latitude: { type: :number },
                                       config: { type: :raw },
                                       registered_on: { type: :date },
                                       lock_version: { type: :integer })
    end
  end

  describe '#write_attribute' do
    it 'writes attribute on the model' do
      klass = new_class do
        field :count, :integer
      end

      obj = klass.new
      obj.write_attribute(:count, 10)
      expect(obj.attributes[:count]).to eql(10)
    end

    it 'returns self' do
      klass = new_class do
        field :count, :integer
      end

      obj = klass.new
      result = obj.write_attribute(:count, 10)
      expect(result).to eql(obj)
    end

    it 'writes an attribute with an alias' do
      skip "should be fixed"
      address[:CityName] = 'Chicago'
      expect(address.city).to eq 'Chicago'
    end

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

    it 'raises an UnknownAttribute error if the attribute is not on the model' do
      obj = new_class.new

      expect {
        obj.write_attribute(:name, 'Alex')
      }.to raise_error Dynamoid::Errors::UnknownAttribute
    end

    it 'marks an attribute as changed' do
      klass = new_class do
        field :name
      end

      obj = klass.new
      obj.write_attribute(:name, 'Alex')
      expect(obj.name_changed?).to eq true
    end

    it 'does not mark an attribute as changed if new value equals the old one' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')
      obj = klass.find(obj.id)

      obj.write_attribute(:name, 'Alex')
      expect(obj.name_changed?).to eq false
    end
  end

  describe '#read_attribute' do
    let(:address) { Address.create(deliverable: true) }
    let(:original_id) { address.id }


    it 'reads a written attribute' do
      address.city = 'Chicago'
      expect(address.read_attribute(:city)).to eq 'Chicago'
    end

    it 'reads a written attribute with the alias' do
      skip "should be fixed"
      address.write_attribute(:city, 'Chicago')
      expect(address[:CityName]).to eq 'Chicago'
    end
  end

  context 'implicitly declared attribute' do
    it 'automatically declares id' do
      expect { address.id }.not_to raise_error
    end

    describe 'timestamps fields `created_at` and `updated_at`' do
      let(:class_with_timestamps_true) do
        new_class do
          table timestamps: true
        end
      end

      let(:class_with_timestamps_false) do
        new_class do
          table timestamps: false
        end
      end

      it 'declares timestamps when Dynamoid::Config.timestamps = true', config: { timestamps: true } do
        expect(new_class.attributes).to have_key(:created_at)
        expect(new_class.attributes).to have_key(:updated_at)

        expect(new_class.new).to respond_to(:created_at)
        expect(new_class.new).to respond_to(:updated_at)
      end

      it 'does not declare timestamps when Dynamoid::Config.timestamps = false', config: { timestamps: false } do
        expect(new_class.attributes).not_to have_key(:created_at)
        expect(new_class.attributes).not_to have_key(:updated_at)

        expect(new_class.new).not_to respond_to(:created_at)
        expect(new_class.new).not_to respond_to(:updated_at)
      end

      it 'does not declare timestamps when Dynamoid::Config.timestamps = true but table timestamps = false', config: { timestamps: true } do
        expect(class_with_timestamps_false.attributes).not_to have_key(:created_at)
        expect(class_with_timestamps_false.attributes).not_to have_key(:updated_at)

        expect(class_with_timestamps_false.new).not_to respond_to(:created_at)
        expect(class_with_timestamps_false.new).not_to respond_to(:updated_at)
      end

      it 'declares timestamps when Dynamoid::Config.timestamps = false but table timestamps = true', config: { timestamps: false } do
        expect(class_with_timestamps_true.attributes).to have_key(:created_at)
        expect(class_with_timestamps_true.attributes).to have_key(:updated_at)

        expect(class_with_timestamps_true.new).to respond_to(:created_at)
        expect(class_with_timestamps_true.new).to respond_to(:updated_at)
      end
    end
  end
end
