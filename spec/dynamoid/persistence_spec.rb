# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Persistence do
  let(:address) { Address.new }

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid.adapter.delete_table(Address.table_name) if Dynamoid.adapter.list_tables.include?(Address.table_name)
      end

      it 'creates a table' do
        Address.create_table(table_name: Address.table_name)

        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(table_name: Address.table_name)

        expect(Address.table_exists?(Address.table_name)).to be_truthy
        expect(Address.table_exists?('crazytable')).to be_falsey
      end
    end
  end

  describe '.create_table' do
    let(:user_class) do
      Class.new do
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

        def self.dynamoid_load(string)
          new(string.to_s)
        end
      end
    end

    let(:user_class_with_type) do
      Class.new do
        attr_accessor :age

        def initialize(age)
          self.age = age
        end

        def dynamoid_dump
          age
        end

        def eql?(other)
          age == other.age
        end

        def self.dynamoid_load(string)
          new(string.to_i)
        end

        def self.dynamoid_field_type
          :number
        end
      end
    end

    describe 'partition key attribute type' do
      it 'maps :string to String' do
        klass = new_class(partition_key: { name: :id, type: :string })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
      end

      it 'maps :integer to Number' do
        klass = new_class(partition_key: { name: :id, type: :integer })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
      end

      it 'maps :number to Number' do
        klass = new_class(partition_key: { name: :id, type: :number })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
      end

      describe ':datetime' do
        it 'maps :datetime to Number' do
          klass = new_class(partition_key: { name: :id, type: :datetime })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        it 'maps :datetime to String if field option :store_as_string is true' do
          klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: true } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'maps :datetime to Number if field option :store_as_string is false' do
          klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: false } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :datetime to String if :store_datetime_as_string is true', config: { store_datetime_as_string: true } do
            klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
          end

          it 'maps :datetime to Number if :store_datetime_as_string is false', config: { store_datetime_as_string: false } do
            klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
          end
        end
      end

      describe ':date' do
        it 'maps :date to Number' do
          klass = new_class(partition_key: { name: :id, type: :date })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        it 'maps :date to String if field option :store_as_string is true' do
          klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: true } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'maps :date to Number if field option :store_as_string is false' do
          klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: false } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :date to String if :store_date_as_string is true', config: { store_date_as_string: true } do
            klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
          end

          it 'maps :date to Number if :store_date_as_string is false', config: { store_date_as_string: false } do
            klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
          end
        end
      end

      it 'maps :serialized to String' do
        klass = new_class(partition_key: { name: :id, type: :serialized })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
      end

      describe 'custom type' do
        it 'maps custom type to String by default' do
          klass = new_class(partition_key: { name: :id, type: user_class })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'uses specified type if .dynamoid_field_type method declared' do
          klass = new_class(partition_key: { name: :id, type: user_class_with_type })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end
      end

      it 'does not support :array' do
        klass = new_class(partition_key: { name: :id, type: :array })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'array cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :set' do
        klass = new_class(partition_key: { name: :id, type: :set })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'set cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :raw' do
        klass = new_class(partition_key: { name: :id, type: :raw })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'raw cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :boolean' do
        klass = new_class(partition_key: { name: :id, type: :boolean })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'boolean cannot be used as a type of table key attribute'
        )
      end
    end

    describe 'sort key attribute type' do
      it 'maps :string to String' do
        klass = new_class do
          range :prop, :string
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
      end

      it 'maps :integer to Number' do
        klass = new_class do
          range :prop, :integer
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
      end

      it 'maps :number to Number' do
        klass = new_class do
          range :prop, :number
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
      end

      describe ':datetime' do
        it 'maps :datetime to Number' do
          klass = new_class do
            range :prop, :datetime
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        it 'maps :datetime to String if field option :store_as_string is true' do
          klass = new_class do
            range :prop, :datetime, store_as_string: true
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'maps :datetime to Number if field option :store_as_string is false' do
          klass = new_class do
            range :prop, :datetime, store_as_string: false
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :datetime to String if :store_datetime_as_string is true', config: { store_datetime_as_string: true } do
            klass = new_class do
              range :prop, :datetime, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
          end

          it 'maps :datetime to Number if :store_datetime_as_string is false', config: { store_datetime_as_string: false } do
            klass = new_class do
              range :prop, :datetime, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
          end
        end
      end

      describe ':date' do
        it 'maps :date to Number' do
          klass = new_class do
            range :prop, :date
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        it 'maps :date to String if field option :store_as_string is true' do
          klass = new_class do
            range :prop, :date, store_as_string: true
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'maps :date to Number if field option :store_as_string is false' do
          klass = new_class do
            range :prop, :date, store_as_string: false
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :date to String if :store_date_as_string is true', config: { store_date_as_string: true } do
            klass = new_class do
              range :prop, :date, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
          end

          it 'maps :date to Number if :store_date_as_string is false', config: { store_date_as_string: false } do
            klass = new_class do
              range :prop, :date, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
          end
        end
      end

      it 'maps :serialized to String' do
        klass = new_class do
          range :prop, :serialized
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
      end

      describe 'custom type' do
        it 'maps custom type to String by default' do
          klass = new_class(sort_key_type: user_class) do |options|
            range :prop, options[:sort_key_type]
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'uses specified type if .dynamoid_field_type method declared' do
          klass = new_class(sort_key_type: user_class_with_type) do |options|
            range :prop, options[:sort_key_type]
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end
      end

      it 'does not support :array' do
        klass = new_class do
          range :prop, :array
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'array cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :set' do
        klass = new_class do
          range :prop, :set
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'set cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :raw' do
        klass = new_class do
          range :prop, :raw
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'raw cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :boolean' do
        klass = new_class do
          range :prop, :boolean
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'boolean cannot be used as a type of table key attribute'
        )
      end
    end

    describe 'expires (Time To Live)' do
      let(:class_with_expiration) do
        new_class do
          table expires: { field: :ttl, after: 60 }
          field :ttl, :integer
        end
      end

      it 'sets up TTL for table' do
        expect(Dynamoid.adapter).to receive(:update_time_to_live)
          .with(table_name: class_with_expiration.table_name, attribute: :ttl)
          .and_call_original

        class_with_expiration.create_table
      end
    end

    describe 'capacity mode' do
      # when capacity mode is PROVISIONED DynamoDB returns billing_mode_summary=nil
      let(:table_description) { Dynamoid.adapter.adapter.send(:describe_table, model.table_name) }
      let(:billing_mode)      { table_description.schema.billing_mode_summary&.billing_mode }

      before do
        model.create_table
      end

      context 'when global config option capacity_mode=on_demand', config: { capacity_mode: :on_demand } do
        context 'when capacity_mode=provisioned in table' do
          let(:model) do
            new_class do
              table capacity_mode: :provisioned
            end
          end

          it 'creates table with provisioned capacity mode' do
            expect(billing_mode).to eq nil # it means 'PROVISIONED'
          end
        end

        context 'when capacity_mode not set in table' do
          let(:model) do
            new_class do
              table capacity_mode: nil
            end
          end

          it 'creates table with on-demand capacity mode' do
            expect(billing_mode).to eq 'PAY_PER_REQUEST'
          end
        end
      end

      context 'when global config option capacity_mode=provisioned', config: { capacity_mode: :provisioned } do
        context 'when capacity_mode=on_demand in table' do
          let(:model) do
            new_class do
              table capacity_mode: :on_demand
            end
          end

          it 'creates table with on-demand capacity mode' do
            expect(billing_mode).to eq 'PAY_PER_REQUEST'
          end
        end

        context 'when capacity_mode not set in table' do
          let(:model) do
            new_class do
              table capacity_mode: nil
            end
          end

          it 'creates table with provisioned capacity mode' do
            expect(billing_mode).to eq nil # it means 'PROVISIONED'
          end
        end
      end

      context 'when global config option capacity_mode is not set', config: { capacity_mode: nil } do
        let(:model) do
          new_class do
            table capacity_mode: nil
          end
        end

        it 'creates table with provisioned capacity mode' do
          expect(billing_mode).to eq nil # it means 'PROVISIONED'
        end
      end
    end
  end

  describe 'delete_table' do
    it 'deletes the table' do
      Address.create_table
      Address.delete_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(Address.table_name)).to be_falsey
    end
  end

  describe 'record deletion' do
    let(:klass) do
      new_class do
        field :city

        before_destroy do |_i|
          # Halting the callback chain in active record changed with Rails >= 5.0.0.beta1
          # We now have to throw :abort to halt the callback chain
          # See: https://github.com/rails/rails/commit/bb78af73ab7e86fd9662e8810e346b082a1ae193
          if ActiveModel::VERSION::MAJOR < 5
            false
          else
            throw :abort
          end
        end
      end
    end

    describe 'destroy' do
      it 'deletes an item completely' do
        @user = User.create(name: 'Josh')
        @user.destroy

        expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
      end

      it 'returns false when destroy fails (due to callback)' do
        a = klass.create!
        expect(a.destroy).to eql false
        expect(klass.first.id).to eql a.id
      end
    end

    describe 'destroy!' do
      it 'deletes the item' do
        address.save!
        address.destroy!
        expect(Address.count).to eql 0
      end

      it 'raises exception when destroy fails (due to callback)' do
        a = klass.create!
        expect { a.destroy! }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
      end
    end
  end


  it 'has a table name' do
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
  end

  context 'with namespace is empty' do
    def reload_address
      Object.send(:remove_const, 'Address')
      load 'app/models/address.rb'
    end

    namespace = Dynamoid::Config.namespace

    before do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = ''
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = namespace
      end
    end

    it 'does not add a namespace prefix to table names' do
      table_name = Address.table_name
      expect(Dynamoid::Config.namespace).to be_empty
      expect(table_name).to eq 'addresses'
    end
  end

  it 'deletes an item completely' do
    @user = User.create(name: 'Josh')
    @user.destroy

    expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
  end

  describe '.create' do
    let(:klass) do
      new_class do
        field :city
      end
    end

    it 'creates a new document' do
      address = klass.create(city: 'Chicago')

      expect(address.new_record).to eql false
      expect(address.id).to be_present

      address_saved = klass.find(address.id)
      expect(address_saved.city).to eq('Chicago')
    end

    it 'creates multiple documents' do
      addresses = klass.create([{ city: 'Chicago' }, { city: 'New York' }])

      expect(addresses.size).to eq 2
      expect(addresses).to be_all(&:persisted?)
      expect(addresses[0].city).to eq 'Chicago'
      expect(addresses[1].city).to eq 'New York'
    end

    describe 'validation' do
      let(:klass_with_validation) do
        new_class do
          field :name
          validates :name, length: { minimum: 4 }
        end
      end

      it 'does not save invalid model' do
        obj = klass_with_validation.create(name: 'Theodor')
        expect(obj).to be_persisted

        obj = klass_with_validation.create(name: 'Mo')
        expect(obj).not_to be_persisted
      end

      it 'saves valid models even if there are invalid' do
        obj1, obj2 = klass_with_validation.create([{ name: 'Theodor' }, { name: 'Mo' }])

        expect(obj1).to be_persisted
        expect(obj2).not_to be_persisted
      end
    end

    it 'works with a HashWithIndifferentAccess argument' do
      attrs = ActiveSupport::HashWithIndifferentAccess.new(city: 'Atlanta')
      obj = klass.create(attrs)

      expect(obj).to be_persisted
      expect(obj.city).to eq 'Atlanta'
    end

    it 'creates table if it does not exist' do
      expect {
        klass.create(city: 'Chicago')
      }.to change {
        tables_created.include?(klass.table_name)
      }.from(false).to(true)
    end

    describe 'callbacks' do
      it 'runs before_create callback' do
        klass_with_callback = new_class do
          field :name
          before_create { print 'run before_create' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_create').to_stdout
      end

      it 'runs after_create callback' do
        klass_with_callback = new_class do
          field :name
          after_create { print 'run after_create' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run after_create').to_stdout
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name
          before_save { print 'run before_save' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_save').to_stdout
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          field :name
          after_save { print 'run after_save' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run after_save').to_stdout
      end

      it 'runs callback specified with method name' do
        klass_with_callback = new_class do
          field :name
          before_create :log_message

          def log_message
            print 'run before_create'
          end
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_create').to_stdout
      end
    end

    context 'not unique primary key' do
      context 'composite key' do
        let(:klass_with_composite_key) do
          new_class do
            range :name
          end
        end

        it 'raises RecordNotUnique error' do
          klass_with_composite_key.create(id: '10', name: 'aaa')

          expect {
            klass_with_composite_key.create(id: '10', name: 'aaa')
          }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end

      context 'simple key' do
        let(:klass_with_simple_key) do
          new_class
        end

        it 'raises RecordNotUnique error' do
          klass_with_simple_key.create(id: '10')

          expect {
            klass_with_simple_key.create(id: '10')
          }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class
      end

      it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          time_now = Time.now
          obj = klass.create

          expect(obj.created_at.to_i).to eql(time_now.to_i)
          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          created_at = updated_at = Time.now
          obj = klass.create(created_at: created_at, updated_at: updated_at)

          expect(obj.created_at.to_i).to eql(created_at.to_i)
          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        expect { klass.create }.not_to raise_error
      end
    end
  end

  describe '.create!' do
    context 'validation' do
      let(:klass_with_validation) do
        new_class do
          field :city
          validates :city, presence: true
        end
      end

      it 'raises DocumentNotValid error when saves invalid model' do
        expect do
          klass_with_validation.create!(city: nil)
        end.to raise_error(Dynamoid::Errors::DocumentNotValid)
      end

      it 'raises DocumentNotValid error when saves multiple models and some of them are invalid' do
        expect do
          klass_with_validation.create!([{ city: 'Chicago' }, { city: nil }])
        end.to raise_error(Dynamoid::Errors::DocumentNotValid)
      end

      it 'saves some valid models before raising error because of invalid model' do
        klass_with_validation.create_table

        expect do
          klass_with_validation.create!([{ city: 'Chicago' }, { city: nil }, { city: 'London' }]) rescue nil
        end.to change { klass_with_validation.count }.by(1)

        obj = klass_with_validation.last
        expect(obj.city).to eq 'Chicago'
      end
    end
  end

  describe '.update' do
    let(:document_class) do
      new_class do
        field :name

        validates :name, presence: true, length: { minimum: 5 }
      end
    end

    it 'loads and saves document' do
      d = document_class.create(name: 'Document#1')

      expect do
        document_class.update(d.id, name: '[Updated]')
      end.to change { d.reload.name }.from('Document#1').to('[Updated]')
    end

    it 'returns updated document' do
      d = document_class.create(name: 'Document#1')
      d2 = document_class.update(d.id, name: '[Updated]')

      expect(d2).to be_a(document_class)
      expect(d2.name).to eq '[Updated]'
    end

    it 'does not save invalid document' do
      d = document_class.create(name: 'Document#1')
      d2 = nil

      expect do
        d2 = document_class.update(d.id, name: '[Up')
      end.not_to change { d.reload.name }
      expect(d2).not_to be_valid
    end

    it 'accepts range key value if document class declares it' do
      klass = new_class do
        field :name
        range :status
      end

      d = klass.create(status: 'old', name: 'Document#1')
      expect do
        klass.update(d.id, 'old', name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    it 'dumps range key value to proper format' do
      klass = new_class do
        field :name
        range :activated_on, :date
        field :another_date, :datetime
      end

      d = klass.create(activated_on: '2018-01-14'.to_date, name: 'Document#1')
      expect do
        klass.update(d.id, '2018-01-14'.to_date, name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.update(d.id, name: '[Updated]')
          }.to change { d.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.update(d.id, name: '[Updated]', updated_at: updated_at)
          }.to change { d.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        doc = document_class.create(name: 'Document#1')

        expect do
          document_class.update(doc.id, name: '[Updated]')
        end.not_to raise_error
      end
    end

    describe 'type casting' do
      it 'uses type casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.update(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end
  end

  describe '.update_fields' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.update_fields(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.update_fields(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.update_fields(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'condition specified' do
      it 'updates when model matches conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 1 })
        }.to change { document_class.find(obj.id).title }.to('New title')
      end

      it 'does not update when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          result = document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
        }.not_to change { document_class.find(obj.id).title }
      end

      it 'returns nil when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        result = document_class.update_fields(obj.id, { title: 'New title' }, if: { version: 6 })
        expect(result).to eq nil
      end
    end

    it 'does not create new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.update_fields('some-fake-id', title: 'Title')
      end.not_to change { document_class.count }
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.update_fields(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.update_fields(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.update_fields(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.update_fields(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.update_fields(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = document_class.create(title: 'Old title')

        expect do
          document_class.update_fields(obj.id, title: 'New title')
        end.not_to raise_error
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.update_fields(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update_fields(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          klass.update_fields(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end

  describe '.upsert' do
    let(:document_class) do
      new_class do
        field :title
        field :version, :integer
        field :published_on, :date
      end
    end

    it 'changes field value' do
      obj = document_class.create(title: 'Old title')
      expect do
        document_class.upsert(obj.id, title: 'New title')
      end.to change { document_class.find(obj.id).title }.from('Old title').to('New title')
    end

    it 'changes field value to nil' do
      obj = document_class.create(title: 'New Document')
      expect do
        document_class.upsert(obj.id, title: nil)
      end.to change { document_class.find(obj.id).title }.from('New Document').to(nil)
    end

    it 'returns updated document' do
      obj = document_class.create(title: 'Old title')
      result = document_class.upsert(obj.id, title: 'New title')

      expect(result.id).to eq obj.id
      expect(result.title).to eq 'New title'
    end

    context 'conditions specified' do
      it 'updates when model matches conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          document_class.upsert(obj.id, { title: 'New title' }, if: { version: 1 })
        }.to change { document_class.find(obj.id).title }.to('New title')
      end

      it 'does not update when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        expect {
          result = document_class.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
        }.not_to change { document_class.find(obj.id).title }
      end

      it 'returns nil when model does not match conditions' do
        obj = document_class.create(title: 'Old title', version: 1)

        result = document_class.upsert(obj.id, { title: 'New title' }, if: { version: 6 })
        expect(result).to eq nil
      end
    end

    it 'creates new document if it does not exist yet' do
      document_class.create_table

      expect do
        document_class.upsert('not-existed-id', title: 'Title')
      end.to change { document_class.count }

      obj = document_class.find('not-existed-id')
      expect(obj.title).to eq 'Title'
    end

    it 'accepts range key if it is declared' do
      document_class_with_range = new_class do
        field :title
        range :category
      end

      obj = document_class_with_range.create(category: 'New')

      expect do
        document_class_with_range.upsert(obj.id, 'New', title: '[Updated]')
      end.to change {
        document_class_with_range.find(obj.id, range_key: 'New').title
      }.to('[Updated]')
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      document_class_with_range = new_class do
        field :title
        range :published_on, :date
      end

      obj = document_class_with_range.create(title: 'Old', published_on: '2018-02-23'.to_date)
      document_class_with_range.upsert(obj.id, '2018-02-23'.to_date, title: 'New')
      expect(obj.reload.title).to eq 'New'
    end

    it 'dumps attributes values' do
      obj = document_class.create
      document_class.upsert(obj.id, published_on: '2018-02-23'.to_date)
      attributes = Dynamoid.adapter.get_item(document_class.table_name, obj.id)
      expect(attributes[:published_on]).to eq 17_585
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.upsert(obj.id, title: 'New title')
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = document_class.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.upsert(obj.id, title: 'New title', updated_at: updated_at)
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = document_class.create(title: 'Old title')

        expect do
          document_class.upsert(obj.id, title: 'New title')
        end.not_to raise_error
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.upsert(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.upsert(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          klass.upsert(a.id, hash: { 1 => :b })
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end

  describe '.inc' do
    let(:document_class) do
      new_class do
        field :links_count, :integer
        field :mentions_count, :integer
      end
    end

    it 'adds specified value' do
      obj = document_class.create!(links_count: 2)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
    end

    it 'accepts negative value' do
      obj = document_class.create!(links_count: 10)

      expect {
        document_class.inc(obj.id, links_count: -2)
      }.to change { document_class.find(obj.id).links_count }.from(10).to(8)
    end

    it 'traits nil value as zero' do
      obj = document_class.create!(links_count: nil)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(nil).to(5)
    end

    it 'supports passing several attributes at once' do
      obj = document_class.create!(links_count: 2, mentions_count: 31)
      document_class.inc(obj.id, links_count: 5, mentions_count: 9)

      expect(document_class.find(obj.id).links_count).to eql(7)
      expect(document_class.find(obj.id).mentions_count).to eql(40)
    end

    it 'accepts sort key if it is declared' do
      class_with_sort_key = new_class do
        range :author_name
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(author_name: 'Mike', links_count: 2)
      class_with_sort_key.inc(obj.id, 'Mike', links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      class_with_sort_key = new_class do
        range :published_on, :date
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      class_with_sort_key.inc(obj.id, '2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    describe 'timestamps' do
      it 'does not change updated_at', config: { timestamps: true } do
        obj = document_class.create!
        expect(obj.updated_at).to be_present

        expect {
          document_class.inc(obj.id, links_count: 5)
        }.not_to change { document_class.find(obj.id).updated_at }
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        class_with_sort_key = new_class do
          range :published_on, :date
          field :links_count, :integer
        end

        obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
        class_with_sort_key.inc(obj.id, '2018-10-07', links_count: 5)

        expect(obj.reload.links_count).to eql(7)
      end

      it 'type casts attributes' do
        obj = document_class.create!(links_count: 2)

        expect {
          document_class.inc(obj.id, links_count: '5.12345')
        }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
      end
    end
  end

  describe '.save' do
    let(:klass) do
      new_class do
        field :name
      end
    end

    it 'saves model' do
      obj = klass.new(name: 'Alex')
      obj.save

      expect(klass.exists?(obj.id)).to eq true
      expect(klass.find(obj.id).name).to eq 'Alex'
    end

    it 'marks it as persisted' do
      obj = klass.new(name: 'Alex')
      expect { obj.save }.to change { obj.persisted? }.from(false).to(true)
    end

    it 'creates table if it does not exist' do
      model = klass.new

      expect { model.save }
        .to change { tables_created.include?(klass.table_name) }
        .from(false).to(true)
    end

    it 'dumps attribute values' do
      klass = new_class do
        field :active, :boolean, store_as_native_boolean: false
      end

      obj = klass.new(active: false)
      obj.save!
      expect(raw_attributes(obj)[:active]).to eql('f')
    end

    describe 'partition key value' do
      it 'generates "id" for new model' do
        obj = klass.new
        obj.save

        expect(obj.id).to be_present
        expect(raw_attributes(obj)[:id]).to eql obj.id
      end

      it 'does not override specified "id" for new model' do
        obj = klass.new(id: '1024')

        expect { obj.save }.not_to change { obj.id }
      end

      it 'does not override "id" for persisted model' do
        obj = klass.create
        obj.name = 'Alex'

        expect { obj.save }.not_to change { obj.id }
      end
    end

    describe 'pessimistic locking' do
      let(:klass) do
        new_class do
          field :name
          field :lock_version, :integer
        end
      end

      it 'generates "lock_version" if field declared' do
        obj = klass.new
        obj.save

        expect(obj.lock_version).to eq 1
        expect(raw_attributes(obj)[:lock_version]).to eq 1
      end

      it 'increments "lock_version" if it is declared' do
        obj = klass.create
        obj.name = 'Alex'

        expect { obj.save }.to change { obj.lock_version }.from(1).to(2)
      end

      it 'prevents concurrent writes to tables with a lock_version' do
        # version #1
        obj = klass.create          # lock_version nil -> 1
        obj2 = klass.find(obj.id)   # lock_version = 1

        # version #2
        obj.name = 'Alex'
        obj.save                    # lock_version 1 -> 2
        obj2.name = 'Bob'

        # tries to create version #2 again
        expect {
          obj2.save                 # lock_version 1 -> 2
        }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end
    end

    describe 'callbacks' do
      context 'new model' do
        it 'runs before_create callback' do
          klass_with_callback = new_class do
            field :name
            before_create { print 'run before_create' }
          end

          obj = klass_with_callback.new(name: 'Alex')
          expect { obj.save }.to output('run before_create').to_stdout
        end

        it 'runs after_create callback' do
          klass_with_callback = new_class do
            field :name
            after_create { print 'run after_create' }
          end

          obj = klass_with_callback.new(name: 'Alex')
          expect { obj.save }.to output('run after_create').to_stdout
        end
      end

      context 'persisted model' do
        it 'runs before_create callback' do
          klass_with_callback = new_class do
            field :name
            before_create { print 'run before_create' }
          end

          obj = klass_with_callback.create(name: 'Alex')
          obj.name = 'Bob'

          expect { obj.save }.not_to output('run before_create').to_stdout
        end

        it 'runs after_create callback' do
          klass_with_callback = new_class do
            field :name
            after_create { print 'run after_create' }
          end

          obj = klass_with_callback.create(name: 'Alex')
          obj.name = 'Bob'

          expect { obj.save }.not_to output('run after_create').to_stdout
        end
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name
          before_save { print 'run before_save' }
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('run before_save').to_stdout
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          field :name
          after_save { print 'run after_save' }
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('run after_save').to_stdout
      end

      it 'runs callback specified with method name' do
        klass_with_callback = new_class do
          field :name
          before_save :log_message

          def log_message
            print 'run before_save'
          end
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('run before_save').to_stdout
      end
    end

    context 'not unique primary key' do
      context 'composite key' do
        let(:klass_with_composite_key) do
          new_class do
            range :name
          end
        end

        it 'raises RecordNotUnique error' do
          klass_with_composite_key.create(id: '10', name: 'aaa')
          obj = klass_with_composite_key.new(id: '10', name: 'aaa')

          expect { obj.save }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end

      context 'simple key' do
        let(:klass_with_simple_key) do
          new_class
        end

        it 'raises RecordNotUnique error' do
          klass_with_simple_key.create(id: '10')
          obj = klass_with_simple_key.new(id: '10')

          expect { obj.save }.to raise_error(Dynamoid::Errors::RecordNotUnique)
        end
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = nil
        expect {
          a = klass.new(hash: { 1 => :b })
          a.save!
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      context 'new record' do
        it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
          travel 1.hour do
            time_now = Time.now
            obj = klass.new
            obj.save

            expect(obj.created_at.to_i).to eql(time_now.to_i)
            expect(obj.updated_at.to_i).to eql(time_now.to_i)
          end
        end

        it 'uses provided values of created_at and of updated_at if Config.timestamps=true', config: { timestamps: true } do
          travel 1.hour do
            created_at = updated_at = Time.now
            obj = klass.new(created_at: created_at, updated_at: updated_at)
            obj.save

            expect(obj.created_at.to_i).to eql(created_at.to_i)
            expect(obj.updated_at.to_i).to eql(updated_at.to_i)
          end
        end

        it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
          created_at = updated_at = Time.now
          obj = klass.new

          expect { obj.save }.not_to raise_error
        end
      end

      context 'persisted record' do
        it 'does not change created_at if Config.timestamps=true', config: { timestamps: true } do
          obj = klass.create(title: 'Old title')

          travel 1.hour do
            expect do
              obj.title = 'New title'
              obj.save
            end.not_to change { obj.created_at.to_s }
          end
        end

        it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
          obj = klass.create(title: 'Old title')

          travel 1.hour do
            time_now = Time.now
            obj.title = 'New title'
            obj.save

            expect(obj.updated_at.to_i).to eql(time_now.to_i)
          end
        end

        it 'uses provided value updated_at if Config.timestamps=true', config: { timestamps: true } do
          obj = klass.create(title: 'Old title')

          travel 1.hour do
            updated_at = Time.now
            obj.title = 'New title'
            obj.updated_at = updated_at
            obj.save

            expect(obj.updated_at.to_i).to eql(updated_at.to_i)
          end
        end

        it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
          obj = klass.create(title: 'Old title')
          obj.title = 'New title'

          expect { obj.save }.not_to raise_error
        end
      end
    end

    describe '`store_attribute_with_nil_value` config option' do
      let(:klass) do
        new_class do
          field :age, :integer
        end
      end

      context 'true', config: { store_attribute_with_nil_value: true } do
        it 'keeps document attribute with nil' do
          obj = klass.new(age: nil)
          obj.save

          expect(raw_attributes(obj)).to include(age: nil)
        end
      end

      context 'false', config: { store_attribute_with_nil_value: false } do
        it 'does not keep document attribute with nil' do
          obj = klass.new(age: nil)
          obj.save

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end

      context 'by default', config: { store_attribute_with_nil_value: nil } do
        it 'does not keep document attribute with nil' do
          obj = klass.new(age: nil)
          obj.save

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end
    end
  end

  describe '#update_attribute' do
    describe 'type casting' do
      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create
        obj.update_attribute(:count, '101')
        expect(obj.attributes[:count]).to eql(101)
        expect(raw_attributes(obj)[:count]).to eql(101)
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now
          obj.update_attribute(:title, 'New title')

          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided value updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now
          obj.update_attribute(:updated_at, updated_at)

          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          obj.update_attribute(:title, 'New title')
        end.not_to raise_error
      end
    end
  end

  describe '#update_attributes' do
    let(:klass) do
      new_class do
        field :name
        field :age, :integer
      end
    end

    it 'saves changed attributes' do
      obj = klass.create!(name: 'Mike', age: 26)
      obj.update_attributes(age: 27)

      expect(obj.age).to eql 27
      expect(klass.find(obj.id).age).to eql 27
    end

    it 'saves document if it is not persisted yet' do
      obj = klass.new(name: 'Mike', age: 26)
      obj.update_attributes(age: 27)

      expect(obj).to be_persisted
      expect(obj.age).to eql 27
      expect(klass.find(obj.id).age).to eql 27
    end

    it 'does not save document if validaton fails' do
      klass = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end

      obj = klass.create!(name: 'Mike', age: 26)
      obj.update_attributes(age: 11)

      expect(obj.age).to eql 11
      expect(klass.find(obj.id).age).to eql 26
    end

    describe 'type casting' do
      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create
        obj.update_attributes(count: '101')

        expect(obj.attributes[:count]).to eql(101)
        expect(raw_attributes(obj)[:count]).to eql(101)
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now
          obj.update_attributes(title: 'New title')

          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided value updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now
          obj.update_attributes(updated_at: updated_at, title: 'New title')

          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          obj.update_attributes(title: 'New title')
        end.not_to raise_error
      end
    end
  end

  describe '#update_attributes!' do
    let(:klass) do
      new_class do
        field :name
        field :age, :integer
      end
    end

    it 'saves changed attributes' do
      obj = klass.create!(name: 'Mike', age: 26)
      obj.update_attributes!(age: 27)

      expect(obj.age).to eql 27
      expect(klass.find(obj.id).age).to eql 27
    end

    it 'saves document if it is not persisted yet' do
      obj = klass.new(name: 'Mike', age: 26)
      obj.update_attributes!(age: 27)

      expect(obj).to be_persisted
      expect(obj.age).to eql 27
      expect(klass.find(obj.id).age).to eql 27
    end

    it 'raises DocumentNotValid error if validaton fails' do
      klass = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end
      obj = klass.create!(name: 'Mike', age: 26)

      expect {
        obj.update_attributes!(age: 11)
      }.to raise_error(Dynamoid::Errors::DocumentNotValid)

      expect(obj.age).to eql 11
      expect(klass.find(obj.id).age).to eql 26
    end

    describe 'type casting' do
      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create
        obj.update_attributes!(count: '101')

        expect(obj.attributes[:count]).to eql(101)
        expect(raw_attributes(obj)[:count]).to eql(101)
      end
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now
          obj.update_attributes!(title: 'New title')

          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided value updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now
          obj.update_attributes!(updated_at: updated_at, title: 'New title')

          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          obj.update_attributes!(title: 'New title')
        end.not_to raise_error
      end
    end
  end

  describe '#increment' do
    let(:document_class) do
      new_class do
        field :age, :integer
      end
    end

    it 'increments specified attribute' do
      obj = document_class.new(age: 21)

      expect { obj.increment(:age) }.to change { obj.age }.from(21).to(22)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.new(age: nil)

      expect { obj.increment(:age) }.to change { obj.age }.from(nil).to(1)
    end

    it 'adds specified optional value' do
      obj = document_class.new(age: 21)

      expect { obj.increment(:age, 10) }.to change { obj.age }.from(21).to(31)
    end

    it 'returns self' do
      obj = document_class.new(age: 21)

      expect(obj.increment(:age)).to eql(obj)
    end

    it 'does not save changes' do
      obj = document_class.new(age: 21)
      obj.increment(:age)

      expect(obj).to be_new_record
    end
  end

  describe '#increment!' do
    let(:document_class) do
      new_class do
        field :age, :integer
      end
    end

    it 'increments specified attribute' do
      obj = document_class.new(age: 21)

      expect { obj.increment!(:age) }.to change { obj.age }.from(21).to(22)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.new(age: nil)

      expect { obj.increment!(:age) }.to change { obj.age }.from(nil).to(1)
    end

    it 'adds specified optional value' do
      obj = document_class.new(age: 21)

      expect { obj.increment!(:age, 10) }.to change { obj.age }.from(21).to(31)
    end

    it 'returns true if document is valid' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { less_than: 16 }
      end
      obj = class_with_validation.new(age: 10)

      expect(obj.increment!(:age, 1)).to eql(true)
    end

    it 'returns false if document is invalid' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { less_than: 16 }
      end
      obj = class_with_validation.new(age: 10)

      expect(obj.increment!(:age, 10)).to eql(false)
    end

    it 'saves changes' do
      obj = document_class.new(age: 21)
      obj.increment!(:age)

      expect(obj).to be_persisted
    end
  end

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

  describe '#decrement' do
    let(:document_class) do
      new_class do
        field :age, :integer
      end
    end

    it 'decrements specified attribute' do
      obj = document_class.new(age: 21)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.new(age: nil)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'adds specified optional value' do
      obj = document_class.new(age: 21)

      expect { obj.decrement!(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'returns true if document is valid' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end
      obj = class_with_validation.new(age: 20)

      expect(obj.decrement!(:age, 1)).to eql(true)
    end

    it 'returns false if document is invalid' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end
      obj = class_with_validation.new(age: 20)

      expect(obj.decrement!(:age, 10)).to eql(false)
    end

    it 'saves changes' do
      obj = document_class.new(age: 21)
      obj.decrement!(:age)

      expect(obj).to be_persisted
    end
  end

  context 'update' do
    before :each do
      @tweet = Tweet.create(tweet_id: 1, group: 'abc', count: 5, tags: Set.new(%w[db sql]), user_name: 'john')
    end

    it 'runs before_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_before_update).once.and_return(true)

      CamelCase.create(color: 'blue').update do |t|
        t.set(color: 'red')
      end
    end

    it 'runs after_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_after_update).once.and_return(true)

      CamelCase.create(color: 'blue').update do |t|
        t.set(color: 'red')
      end
    end

    it 'support add/delete operation on a field' do
      @tweet.update do |t|
        t.add(count: 3)
        t.delete(tags: Set.new(['db']))
      end

      expect(@tweet.count).to eq(8)
      expect(@tweet.tags.to_a).to eq(['sql'])
    end

    it 'checks the conditions on update' do
      result = @tweet.update(if: { count: 5 }) do |t|
        t.add(count: 3)
      end
      expect(result).to be_truthy

      expect(@tweet.count).to eq(8)

      result = @tweet.update(if: { count: 5 }) do |t|
        t.add(count: 3)
      end
      expect(result).to be_falsey

      expect(@tweet.count).to eq(8)

      expect do
        @tweet.update!(if: { count: 5 }) do |t|
          t.add(count: 3)
        end
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'prevents concurrent saves to tables with a lock_version' do
      address.save!
      a2 = Address.find(address.id)
      a2.update! { |a| a.set(city: 'Chicago') }

      expect do
        address.city = 'Seattle'
        address.save!
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'uses dumped value of sort key to call UpdateItem' do
      klass = new_class do
        range :activated_on, :date
        field :name
      end
      klass.create_table

      obj = klass.create!(activated_on: Date.today, name: 'Old value')
      obj.update! { |d| d.set(name: 'New value') }

      expect(obj.reload.name).to eql('New value')
    end

    describe 'timestamps' do
      let(:klass) do
        new_class do
          field :title
        end
      end

      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          time_now = Time.now

          expect {
            obj.update { |d| d.set(title: 'New title') }
          }.to change { obj.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        obj = klass.create(title: 'Old title')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            obj.update do |d|
              d.set(title: 'New title')
              d.set(updated_at: updated_at.to_i)
            end
          }.to change { obj.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        obj = klass.create(title: 'Old title')

        expect do
          obj.update { |d| d.set(title: 'New title') }
        end.not_to raise_error
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      it 'works well with hash keys of any type' do
        a = klass.create

        expect {
          a.update { |d| d.set(hash: { 1 => :b }) }
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end

  context 'delete' do
    it 'uses dumped value of sort key to call DeleteItem' do
      klass = new_class do
        range :activated_on, :date
      end

      obj = klass.create!(activated_on: Date.today)

      expect { obj.delete }.to change {
        klass.where(id: obj.id, activated_on: obj.activated_on).first
      }.to(nil)
    end

    context 'with lock version' do
      it 'deletes a record if lock version matches' do
        address.save!
        expect { address.destroy }.to_not raise_error
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.destroy }.to raise_exception(Dynamoid::Errors::StaleObjectError)
      end

      it 'uses the correct lock_version even if it is modified' do
        address.save!
        a1 = address
        a1.lock_version = 100

        expect { a1.destroy }.to_not raise_error
      end
    end
  end

  describe '.import' do
    before do
      Address.create_table
      User.create_table
      Tweet.create_table
    end

    it 'creates multiple documents' do
      expect do
        Address.import([{ city: 'Chicago' }, { city: 'New York' }])
      end.to change { Address.count }.by(2)
    end

    it 'returns created documents' do
      addresses = Address.import([{ city: 'Chicago' }, { city: 'New York' }])
      expect(addresses[0].city).to eq('Chicago')
      expect(addresses[1].city).to eq('New York')
    end

    it 'does not validate documents' do
      klass = new_class do
        field :city
        validates :city, presence: true
      end
      klass.create_table

      addresses = klass.import([{ city: nil }, { city: 'Chicago' }])
      expect(addresses[0].persisted?).to be true
      expect(addresses[1].persisted?).to be true
    end

    it 'does not run callbacks' do
      klass = new_class do
        field :city
        validates :city, presence: true

        before_save { raise 'before save callback called' }
      end
      klass.create_table

      expect { klass.import([{ city: 'Chicago' }]) }.not_to raise_error
    end

    it 'makes batch operation' do
      expect(Dynamoid.adapter).to receive(:batch_write_item).and_call_original
      Address.import([{ city: 'Chicago' }, { city: 'New York' }])
    end

    it 'supports empty containers in `serialized` fields' do
      users = User.import([name: 'Philip', favorite_colors: Set.new])

      user = User.find(users[0].id)
      expect(user.favorite_colors).to eq Set.new
    end

    it 'supports array being empty' do
      users = User.import([{ todo_list: [] }])

      user = User.find(users[0].id)
      expect(user.todo_list).to eq []
    end

    it 'saves empty set as nil' do
      tweets = Tweet.import([{ group: 'one', tags: [] }])

      tweet = Tweet.find_by_tweet_id(tweets[0].tweet_id)
      expect(tweet.tags).to eq nil
    end

    it 'saves empty string as nil' do
      users = User.import([{ name: '' }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'saves attributes with nil value' do
      users = User.import([{ name: nil }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'supports container types being nil' do
      users = User.import([{ name: 'Philip', todo_list: nil }])

      user = User.find(users[0].id)
      expect(user.todo_list).to eq nil
    end

    describe 'timestamps' do
      let(:klass) do
        new_class
      end

      before do
        klass.create_table
      end

      it 'sets created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          time_now = Time.now
          obj, = klass.import([{}])

          expect(obj.created_at.to_i).to eql(time_now.to_i)
          expect(obj.updated_at.to_i).to eql(time_now.to_i)
        end
      end

      it 'uses provided values of created_at and updated_at if Config.timestamps=true', config: { timestamps: true } do
        travel 1.hour do
          created_at = updated_at = Time.now
          obj, = klass.import([{ created_at: created_at, updated_at: updated_at }])

          expect(obj.created_at.to_i).to eql(created_at.to_i)
          expect(obj.updated_at.to_i).to eql(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        expect { klass.import([{}]) }.not_to raise_error
      end
    end

    it 'dumps attribute values' do
      klass = new_class do
        field :active, :boolean, store_as_native_boolean: false
      end
      klass.create_table

      objects = klass.import([{ active: false }])
      obj = objects[0]
      obj.save!
      expect(raw_attributes(obj)[:active]).to eql('f')
    end

    it 'type casts attributes' do
      klass = new_class do
        field :count, :integer
      end
      klass.create_table

      objects = klass.import([{ count: '101' }])
      obj = objects[0]
      expect(obj.attributes[:count]).to eql(101)
      expect(raw_attributes(obj)[:count]).to eql(101)
    end

    context 'backoff is specified' do
      let(:backoff_strategy) do
        ->(_) { -> { @counter += 1 } }
      end

      before do
        @old_backoff = Dynamoid.config.backoff
        @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

        @counter = 0
        Dynamoid.config.backoff_strategies[:simple] = backoff_strategy
        Dynamoid.config.backoff = { simple: nil }
      end

      after do
        Dynamoid.config.backoff = @old_backoff
        Dynamoid.config.backoff_strategies = @old_backoff_strategies
      end

      it 'creates multiple documents' do
        expect do
          Address.import([{ city: 'Chicago' }, { city: 'New York' }])
        end.to change { Address.count }.by(2)
      end

      it 'uses specified backoff when some items are not processed' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        items = (1..3).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '3' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        klass.import(items)
        expect(@counter).to eq 2
      end

      it 'uses new backoff after successful call without unprocessed items' do
        # dynamodb-local ignores provisioned throughput settings
        # so we cannot emulate unprocessed items - let's stub

        klass = new_class
        table_name = klass.table_name
        # batch_write_item processes up to 15 items at once
        # so we emulate 4 calls with items
        items = (1..50).map(&:to_s).map { |id| { id: id } }

        responses = [
          double('response 1', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil),
          double('response 2', unprocessed_items: { table_name => [
                   double(put_request: double(item: { id: '25' }))
                 ] }),
          double('response 3', unprocessed_items: nil)
        ]
        allow(Dynamoid.adapter.client).to receive(:batch_write_item).and_return(*responses)

        expect(backoff_strategy).to receive(:call).exactly(2).times.and_call_original
        klass.import(items)
        expect(@counter).to eq 2
      end
    end

    context ':raw field' do
      let(:klass) do
        new_class do
          field :hash, :raw
        end
      end

      before do
        klass.create_table
      end

      it 'works well with hash keys of any type' do
        a = nil
        expect {
          a, = klass.import([hash: { 1 => :b }])
        }.not_to raise_error

        expect(klass.find(a.id)[:hash]).to eql('1': 'b')
      end
    end
  end
end
