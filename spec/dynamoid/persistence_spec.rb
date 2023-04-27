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

        expect(Address).to be_table_exists(Address.table_name)
        expect(Address).not_to be_table_exists('crazytable')
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

    it 'creates a table' do
      klass = new_class

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq false

      klass.create_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq true
    end

    it 'returns self' do
      klass = new_class
      expect(klass.create_table).to eq(klass)
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

    describe 'expiring (Time To Live)' do
      let(:class_with_expiration) do
        new_class do
          table expires: { field: :ttl, after: 60 }
          field :ttl, :integer
        end
      end

      it 'sets up TTL for table' do
        expect(Dynamoid.adapter).to receive(:update_time_to_live)
          .with(class_with_expiration.table_name, :ttl)
          .and_call_original

        class_with_expiration.create_table
      end

      it 'sets up TTL for table with specified table_name' do
        table_name = "#{class_with_expiration.table_name}_alias"

        expect(Dynamoid.adapter).to receive(:update_time_to_live)
          .with(table_name, :ttl)
          .and_call_original

        class_with_expiration.create_table(table_name: table_name)
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
      klass = new_class
      klass.create_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq true

      klass.delete_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq false
    end

    it 'returns self' do
      klass = new_class
      klass.create_table

      result = klass.delete_table

      expect(result).to eq klass
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

    context 'when block specified' do
      it 'calls a block and passes a model as argument' do
        object = klass.create(city: 'a') do |obj|
          obj.city = 'b'
        end

        expect(object.city).to eq('b')
      end

      it 'calls a block and passes each model as argument if there are multiple models' do
        objects = klass.create([{ city: 'a' }, { city: 'b' }]) do |obj|
          obj.city = obj.city * 2
        end

        expect(objects[0].city).to eq('aa')
        expect(objects[1].city).to eq('bb')
      end
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

    it 'saves empty set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create(tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      obj = klass.create(city: '')
      obj_loaded = klass.find(obj.id)

      expect(obj_loaded.city).to eql nil
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

      it 'runs around_create callback' do
        klass_with_callback = new_class do
          field :name
          around_create :around_create_callback

          def around_create_callback
            print 'start around_create'
            yield
            print 'finish around_create'
          end
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('start around_create' + 'finish around_create').to_stdout
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

      it 'runs around_save callback' do
        klass_with_callback = new_class do
          field :name
          around_save :around_save_callback

          def around_save_callback
            print 'start around_save'
            yield
            print 'finish around_save'
          end
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('start around_save' + 'finish around_save').to_stdout
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          field :name
          before_validation { print 'run before_validation' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run before_validation').to_stdout
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          field :name
          after_validation { print 'run after_validation' }
        end

        expect do
          klass_with_callback.create(name: 'Alex')
        end.to output('run after_validation').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_create { puts 'run before_create' }
          after_create { puts 'run after_create' }
          around_create :around_create_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          def around_create_callback
            puts 'start around_create'
            yield
            puts 'finish around_create'
          end

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end
        end

        # print each message on new line to force RSpec to show meaningful diff
        expected_output = [
          'run before_validation',
          'run after_validation',
          'run before_save',
          'start around_save',
          'run before_create',
          'start around_create',
          'finish around_create',
          'run after_create',
          'finish around_save',
          'run after_save'
        ].join("\n") + "\n"

        expect { klass_with_callbacks.create }.to output(expected_output).to_stdout
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
    let(:klass) do
      new_class do
        field :city
      end
    end

    context 'when block specified' do
      it 'calls a block and passes a model as argument' do
        object = klass.create!(city: 'a') do |obj|
          obj.city = 'b'
        end

        expect(object.city).to eq('b')
      end

      it 'calls a block and passes each model as argument if there are multiple models' do
        objects = klass.create!([{ city: 'a' }, { city: 'b' }]) do |obj|
          obj.city = obj.city * 2
        end

        expect(objects[0].city).to eq('aa')
        expect(objects[1].city).to eq('bb')
      end
    end

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
          begin
            klass_with_validation.create!([{ city: 'Chicago' }, { city: nil }, { city: 'London' }])
          rescue StandardError
            nil
          end
        end.to change(klass_with_validation, :count).by(1)

        obj = klass_with_validation.last
        expect(obj.city).to eq 'Chicago'
      end
    end
  end

  describe '.update!' do
    let(:document_class) do
      new_class do
        field :name

        validates :name, presence: true, length: { minimum: 5 }
      end
    end

    it 'loads and saves document' do
      d = document_class.create(name: 'Document#1')

      expect do
        document_class.update!(d.id, name: '[Updated]')
      end.to change { d.reload.name }.from('Document#1').to('[Updated]')
    end

    it 'returns updated document' do
      d = document_class.create(name: 'Document#1')
      d2 = document_class.update!(d.id, name: '[Updated]')

      expect(d2).to be_a(document_class)
      expect(d2.name).to eq '[Updated]'
    end

    it 'does not save invalid document' do
      d = document_class.create(name: 'Document#1')
      d2 = nil

      expect do
        d2 = document_class.update!(d.id, name: '[Up')
      end.to raise_error(Dynamoid::Errors::DocumentNotValid)
      expect(d2).to be_nil
    end

    it 'accepts range key value if document class declares it' do
      klass = new_class do
        field :name
        range :status
      end

      d = klass.create(status: 'old', name: 'Document#1')
      expect do
        klass.update!(d.id, 'old', name: '[Updated]')
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
        klass.update!(d.id, '2018-01-14'.to_date, name: '[Updated]')
      end.to change { d.reload.name }.to('[Updated]')
    end

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')
      expect {
        klass.update!(obj.id, age: 26)
      }.to raise_error Dynamoid::Errors::UnknownAttribute
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.update!(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update!(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    describe 'timestamps' do
      it 'sets updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          time_now = Time.now

          expect {
            document_class.update!(d.id, name: '[Updated]')
          }.to change { d.reload.updated_at.to_i }.to(time_now.to_i)
        end
      end

      it 'uses provided value of updated_at if Config.timestamps=true', config: { timestamps: true } do
        d = document_class.create(name: 'Document#1')

        travel 1.hour do
          updated_at = Time.now + 1.hour

          expect {
            document_class.update!(d.id, name: '[Updated]', updated_at: updated_at)
          }.to change { d.reload.updated_at.to_i }.to(updated_at.to_i)
        end
      end

      it 'does not raise error if Config.timestamps=false', config: { timestamps: false } do
        doc = document_class.create(name: 'Document#1')

        expect do
          document_class.update!(doc.id, name: '[Updated]')
        end.not_to raise_error
      end

      it 'does not change updated_at if attributes were assigned the same values' do
        doc = document_class.create(name: 'Document#1', updated_at: Time.now - 1)

        expect do
          document_class.update!(doc.id, name: doc.name)
        end.not_to change { doc.reload.updated_at }
      end
    end

    describe 'type casting' do
      it 'uses type casted value of sort key to call UpdateItem' do
        document_class_with_range = new_class do
          range :count, :integer
          field :title
        end

        obj = document_class_with_range.create(title: 'Old', count: '100')
        document_class_with_range.update!(obj.id, '100', title: 'New')
        expect(obj.reload.title).to eq 'New'
      end

      it 'type casts attributes' do
        klass = new_class do
          field :count, :integer
        end

        obj = klass.create(count: 100)
        obj2 = klass.update!(obj.id, count: '101')
        expect(obj2.attributes[:count]).to eql(101)
        expect(raw_attributes(obj2)[:count]).to eql(101)
      end
    end

    describe 'callbacks' do
      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :name

          before_update { print 'run before_update' }
        end

        model = klass_with_callback.create(name: 'Document#1')

        expect do
          klass_with_callback.update!(model.id, name: '[Updated]')
        end.to output('run before_update').to_stdout
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :name

          after_update { print 'run after_update' }
        end

        model = klass_with_callback.create(name: 'Document#1')

        expect do
          klass_with_callback.update!(model.id, name: '[Updated]')
        end.to output('run after_update').to_stdout
      end

      it 'runs around_update callback' do
        klass_with_callback = new_class do
          field :name

          around_update :around_update_callback

          def around_update_callback
            print 'start around_update'
            yield
            print 'finish around_update'
          end
        end

        model = klass_with_callback.create(name: 'Document#1')

        expect do
          klass_with_callback.update!(model.id, name: '[Updated]')
        end.to output('start around_update' + 'finish around_update').to_stdout
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name

          before_save { print 'run before_save' }
        end

        expect { # to suppress printing at model creation
          model = klass_with_callback.create(name: 'Document#1')

          expect do
            klass_with_callback.update!(model.id, name: '[Updated]')
          end.to output('run before_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs after_save callback' do
        klass_with_callback = new_class do
          field :name

          after_save { print 'run after_save' }
        end

        expect { # to suppress printing at model creation
          model = klass_with_callback.create(name: 'Document#1')

          expect do
            klass_with_callback.update!(model.id, name: '[Updated]')
          end.to output('run after_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs around_save callback' do
        klass_with_callback = new_class do
          field :name

          around_save :around_save_callback

          def around_save_callback
            print 'start around_save'
            yield
            print 'finish around_save'
          end
        end

        expect { # to suppress printing at model creation
          model = klass_with_callback.create(name: 'Document#1')

          expect do
            klass_with_callback.update!(model.id, name: '[Updated]')
          end.to output('start around_save' + 'finish around_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          field :name

          before_validation { print 'run before_validation' }
        end

        expect { # to suppress printing at model creation
          model = klass_with_callback.create(name: 'Document#1')

          expect do
            klass_with_callback.update!(model.id, name: '[Updated]')
          end.to output('run before_validation').to_stdout
        }.to output.to_stdout
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          field :name

          after_validation { print 'run after_validation' }
        end

        expect { # to suppress printing at model creation
          model = klass_with_callback.create(name: 'Document#1')

          expect do
            klass_with_callback.update!(model.id, name: '[Updated]')
          end.to output('run after_validation').to_stdout
        }.to output.to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :name

          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        # print each message on new line to force RSpec to show meaningful diff
        expected_output = [
          'run before_validation',
          'run after_validation',
          'run before_save',
          'start around_save',
          'run before_update',
          'start around_update',
          'finish around_update',
          'run after_update',
          'finish around_save',
          'run after_save'
        ].join("\n") + "\n"

        expect { # to suppress printing at model creation
          model = klass_with_callbacks.create(name: 'John')

          expect {
            klass_with_callbacks.update!(model.id, name: '[Updated]')
          }.to output(expected_output).to_stdout
        }.to output.to_stdout
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

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')

      expect do
        klass.update(obj.id, name: 'New name', age: 26)
      end.to raise_error Dynamoid::Errors::UnknownAttribute
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.update(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
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

      it 'does not change updated_at if attributes were assigned the same values' do
        doc = document_class.create(name: 'Document#1', updated_at: Time.now - 1)

        expect do
          document_class.update(doc.id, name: doc.name)
        end.not_to change { doc.reload.updated_at }
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
      end.not_to change(document_class, :count)
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

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.update_fields(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.update_fields(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
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

      it 'does not set updated_at if Config.timestamps=true and table timestamps=false', config: { timestamps: true } do
        document_class.table timestamps: false

        obj = document_class.create(title: 'Old title')
        document_class.update_fields(obj.id, title: 'New title')

        expect(obj.reload.attributes).not_to have_key(:updated_at)
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

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = document_class.create(title: 'New Document')

      expect {
        document_class.update_fields(obj.id, { title: 'New title', publisher: 'New publisher' })
      }.to raise_error Dynamoid::Errors::UnknownAttribute
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
      end.to change(document_class, :count)

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

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      klass_with_set.upsert(obj.id, tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      klass_with_string.upsert(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
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

      it 'does not set updated_at if Config.timestamps=true and table timestamps=false', config: { timestamps: true } do
        document_class.table timestamps: false

        obj = document_class.create(title: 'Old title')
        document_class.upsert(obj.id, title: 'New title')

        expect(obj.reload.attributes).not_to have_key(:updated_at)
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

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = document_class.create(title: 'New Document')

      expect {
        document_class.upsert(obj.id, { title: 'New title', publisher: 'New publisher' })
      }.to raise_error Dynamoid::Errors::UnknownAttribute
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

    it 'returns self' do
      obj = document_class.create!(links_count: 2)

      expect(document_class.inc(obj.id, links_count: 5)).to eq(document_class)
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create!(links_count: 2, updated_at: Time.now - 1.day)

      expect { document_class.inc(obj.id, links_count: 5) }.not_to change { document_class.find(obj.id).updated_at }
      expect { document_class.inc(obj.id, links_count: 5, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: name option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
      end

      obj = klass.create!(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

      expect do
        expect do
          klass.inc(obj.id, links_count: 5, touch: :viewed_at)
        end.to change { klass.find(obj.id).updated_at }
      end.to change { klass.find(obj.id).viewed_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: [<name>*] option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
        field :tagged_at, :datetime
      end

      obj = klass.create!(
        age: 21,
        viewed_at: Time.now - 1.day,
        tagged_at: Time.now - 3.days,
        updated_at: Time.now - 2.days
      )

      expect do
        expect do
          expect do
            klass.inc(obj.id, links_count: 5, touch: %i[viewed_at tagged_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end.to change { klass.find(obj.id).tagged_at }
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

  describe '#save' do
    let(:klass) do
      new_class do
        field :name
      end
    end

    let(:klass_with_range_key) do
      new_class do
        field :name
        range :age, :integer
      end
    end

    let(:klass_with_range_key_and_custom_type) do
      new_class do
        field :name
        range :tags, :serialized
      end
    end

    it 'persists new model' do
      obj = klass.new(name: 'Alex')
      obj.save

      expect(klass.exists?(obj.id)).to eq true
      expect(klass.find(obj.id).name).to eq 'Alex'
    end

    it 'saves changes of already persisted model' do
      obj = klass.create!(name: 'Alex')

      obj.name = 'Michael'
      obj.save

      obj_loaded = klass.find(obj.id)
      expect(obj_loaded.name).to eql 'Michael'
    end

    it 'saves changes of already persisted model if range key is declared' do
      obj = klass_with_range_key.create!(name: 'Alex', age: 21)

      obj.name = 'Michael'
      obj.save

      obj_loaded = klass_with_range_key.find(obj.id, range_key: obj.age)
      expect(obj_loaded.name).to eql 'Michael'
    end

    it 'saves changes of already persisted model if range key is declared and its type is not supported by DynamoDB natively' do
      obj = klass_with_range_key_and_custom_type.create!(name: 'Alex', tags: %w[a b])

      obj.name = 'Michael'
      obj.save

      obj_loaded = klass_with_range_key_and_custom_type.find(obj.id, range_key: obj.tags)
      expect(obj_loaded.name).to eql 'Michael'
    end

    it 'marks persisted new model as persisted' do
      obj = klass.new(name: 'Alex')
      expect { obj.save }.to change { obj.persisted? }.from(false).to(true)
    end

    it 'creates table if it does not exist' do
      model = klass.new

      expect(klass).to receive(:create_table).with(sync: true).and_call_original

      expect { model.save }
        .to change { tables_created.include?(klass.table_name) }
        .from(false).to(true)
    end

    it 'dumps attribute values' do
      klass = new_class do
        field :active, :boolean, store_as_native_boolean: false
      end

      obj = klass.new(active: false)
      obj.save
      expect(raw_attributes(obj)[:active]).to eql('f')
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.tags = []
      obj.save
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.name = ''
      obj.save
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'does not make a request to persist a model if there is no any changed attribute' do
      obj = klass.create(name: 'Alex')

      expect(Dynamoid.adapter).to receive(:update_item).and_call_original
      obj.name = 'Michael'
      obj.save!

      expect(Dynamoid.adapter).not_to receive(:update_item).and_call_original
      obj.save!

      expect(Dynamoid.adapter).not_to receive(:update_item)
      obj_loaded = klass.find(obj.id)
      obj_loaded.save!
    end

    it 'returns true if there is no any changed attribute' do
      obj = klass.create(name: 'Alex')
      obj_loaded = klass.find(obj.id)

      expect(obj.save).to eql(true)
      expect(obj_loaded.save).to eql(true)
    end

    it 'calls PutItem for a new record' do
      expect(Dynamoid.adapter).to receive(:write).and_call_original
      klass.create(name: 'Alex')
    end

    it 'calls UpdateItem for already persisted record' do
      klass = new_class do
        field :name
        field :age, :integer
      end

      obj = klass.create!(name: 'Alex', age: 21)
      obj.age = 31

      expect(Dynamoid.adapter).to receive(:update_item).and_call_original
      obj.save
    end

    it 'does not persist changes if a model was deleted' do
      obj = klass.create!(name: 'Alex')
      Dynamoid.adapter.delete_item(klass.table_name, obj.id)

      obj.name = 'Michael'

      expect do
        expect { obj.save }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end.not_to change(klass, :count)
    end

    it 'does not persist changes if a model was deleted and range key is declared' do
      obj = klass_with_range_key.create!(name: 'Alex', age: 21)
      Dynamoid.adapter.delete_item(klass_with_range_key.table_name, obj.id, range_key: obj.age)

      obj.name = 'Michael'

      expect do
        expect { obj.save }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end.not_to change(klass_with_range_key, :count)
    end

    it 'does not persist changes if a model was deleted, range key is declared and its type is not supported by DynamoDB natively' do
      obj = klass_with_range_key_and_custom_type.create!(name: 'Alex', tags: %w[a b])
      Dynamoid.adapter.delete_item(
        obj.class.table_name,
        obj.id,
        range_key: Dynamoid::Dumping.dump_field(obj.tags, klass_with_range_key_and_custom_type.attributes[:tags])
      )

      obj.name = 'Michael'

      expect do
        expect { obj.save }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end.not_to change { obj.class.count }
    end

    context 'when disable_create_table_on_save is false' do
      before do
        Dynamoid.configure do |config|
          @original_create_table_on_save = config.create_table_on_save
          config.create_table_on_save = false
        end
      end

      after do
        Dynamoid.configure do |config|
          config.create_table_on_save = @original_create_table_on_save
        end
      end

      it 'raises Aws::DynamoDB::Errors::ResourceNotFoundException error' do
        model = klass.new

        expect(klass).not_to receive(:create_table)

        expect { model.save! }.to raise_error(Aws::DynamoDB::Errors::ResourceNotFoundException)
      end
    end

    context 'when disable_create_table_on_save is false and the table exists' do
      before do
        Dynamoid.configure do |config|
          @original_create_table_on_save = config.create_table_on_save
          config.create_table_on_save = false
        end
        klass.create_table
      end

      after do
        Dynamoid.configure do |config|
          config.create_table_on_save = @original_create_table_on_save
        end
      end

      it 'persists the model' do
        obj = klass.new(name: 'John')
        obj.save

        expect(klass.exists?(obj.id)).to eq true
        expect(klass.find(obj.id).name).to eq 'John'
      end
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
        obj.save # lock_version 1 -> 2
        obj2.name = 'Bob'

        # tries to create version #2 again
        expect {
          obj2.save # lock_version 1 -> 2
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

        it 'runs around_create callback' do
          klass_with_callback = new_class do
            field :name
            around_create :around_create_callback

            def around_create_callback
              print 'start around_create'
              yield
              print 'finish around_create'
            end
          end

          obj = klass_with_callback.new(name: 'Alex')
          expect { obj.save }.to output('start around_create' + 'finish around_create').to_stdout
        end

        it 'runs callbacks in the proper order' do
          klass_with_callbacks = new_class do
            before_validation { puts 'run before_validation' }
            after_validation { puts 'run after_validation' }

            before_create { puts 'run before_create' }
            after_create { puts 'run after_create' }
            around_create :around_create_callback

            before_save { puts 'run before_save' }
            after_save { puts 'run after_save' }
            around_save :around_save_callback

            def around_create_callback
              puts 'start around_create'
              yield
              puts 'finish around_create'
            end

            def around_save_callback
              puts 'start around_save'
              yield
              puts 'finish around_save'
            end
          end
          obj = klass_with_callbacks.new(name: 'Alex')

          # print each message on new line to force RSpec to show meaningful diff
          expected_output = [
            'run before_validation',
            'run after_validation',
            'run before_save',
            'start around_save',
            'run before_create',
            'start around_create',
            'finish around_create',
            'run after_create',
            'finish around_save',
            'run after_save'
          ].join("\n") + "\n"

          expect { obj.save }.to output(expected_output).to_stdout
        end
      end

      context 'persisted model' do
        it 'runs before_update callback' do
          klass_with_callback = new_class do
            field :name
            before_update { print 'run before_update' }
          end

          obj = klass_with_callback.create(name: 'Alex')
          obj.name = 'Bob'

          expect { obj.save }.to output('run before_update').to_stdout
        end

        it 'runs after_update callback' do
          klass_with_callback = new_class do
            field :name
            after_update { print 'run after_update' }
          end

          obj = klass_with_callback.create(name: 'Alex')
          obj.name = 'Bob'

          expect { obj.save }.to output('run after_update').to_stdout
        end

        it 'runs around_update callback' do
          klass_with_callback = new_class do
            field :name
            around_update :around_update_callback

            def around_update_callback
              print 'start around_update'
              yield
              print 'finish around_update'
            end
          end

          obj = klass_with_callback.create(name: 'Alex')
          expect { obj.save }.to output('start around_update' + 'finish around_update').to_stdout
        end

        it 'runs callbacks in the proper order' do
          klass_with_callbacks = new_class do
            field :name

            before_validation { puts 'run before_validation' }
            after_validation { puts 'run after_validation' }

            before_update { puts 'run before_update' }
            after_update { puts 'run after_update' }
            around_update :around_update_callback

            before_save { puts 'run before_save' }
            after_save { puts 'run after_save' }
            around_save :around_save_callback

            def around_update_callback
              puts 'start around_update'
              yield
              puts 'finish around_update'
            end

            def around_save_callback
              puts 'start around_save'
              yield
              puts 'finish around_save'
            end
          end

          # print each message on new line to force RSpec to show meaningful diff
          expected_output = [
            'run before_validation',
            'run after_validation',
            'run before_save',
            'start around_save',
            'run before_update',
            'start around_update',
            'finish around_update',
            'run after_update',
            'finish around_save',
            'run after_save'
          ].join("\n") + "\n"

          expect { # to suppress printing at model creation
            obj = klass_with_callbacks.create(name: 'John')
            obj.name = 'Bob'

            expect { obj.save }.to output(expected_output).to_stdout
          }.to output.to_stdout
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

      it 'runs around_save callbacks' do
        klass_with_callback = new_class do
          field :name
          around_save :around_save_callback

          def around_save_callback
            print 'start around_save'
            yield
            print 'finish around_save'
          end
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('start around_save' + 'finish around_save').to_stdout
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          field :name
          before_validation { print 'run before_validation' }
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('run before_validation').to_stdout
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          field :name
          after_validation { print 'run after_validation' }
        end

        obj = klass_with_callback.new(name: 'Alex')
        expect { obj.save }.to output('run after_validation').to_stdout
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

        it 'does not change updated_at if there are no changes' do
          obj = klass.create(title: 'Old title', updated_at: Time.now - 1)

          expect { obj.save }.not_to change { obj.updated_at }
        end

        it 'does not change updated_at if attributes were assigned the same values' do
          obj = klass.create(title: 'Old title', updated_at: Time.now - 1)
          obj.title = obj.title

          expect { obj.save }.not_to change { obj.updated_at }
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

    context 'when `touch: false` option passed' do
      it 'does not update updated_at attribute' do
        obj = klass.create!
        updated_at = obj.updated_at

        travel 1.minute do
          obj.name = 'foo'
          obj.save(touch: false)
        end

        expect(obj.updated_at).to eq updated_at
      end

      it 'sets updated_at attribute for a new record' do
        obj = klass.new(name: 'foo')
        obj.save(touch: false)

        expect(klass.find(obj.id).updated_at).to be_present
      end
    end
  end

  describe '#update_attribute' do
    it 'changes the attribute value' do
      klass = new_class do
        field :age, :integer
      end

      obj = klass.create(age: 18)

      expect { obj.update_attribute(:age, 20) }.to change { obj.age }.from(18).to(20)
    end

    it 'persists the model' do
      klass = new_class do
        field :age, :integer
      end

      obj = klass.create(age: 18)
      obj.update_attribute(:age, 20)

      expect(klass.find(obj.id).age).to eq(20)
    end

    it 'skips validation and saves not valid models' do
      klass = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 0 }
      end

      obj = klass.create(age: 18)
      obj.update_attribute(:age, -1)

      expect(klass.find(obj.id).age).to eq(-1)
    end

    it 'returns self' do
      klass = new_class do
        field :age, :integer
      end

      obj = klass.create(age: 18)
      result = obj.update_attribute(:age, 20)

      expect(result).to eq(obj)
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.update_attribute(:tags, [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

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

      it 'does not change updated_at if attributes were assigned the same values' do
        obj = klass.create(title: 'Old title', updated_at: Time.now - 1)
        obj.title = obj.title

        expect do
          obj.update_attribute(:title, 'Old title')
        end.not_to change { obj.updated_at }
      end
    end

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      klass = new_class do
        field :age, :integer
        field :name, :string
      end

      obj = klass.create!(name: 'Alex', age: 26)

      expect {
        obj.update_attribute(:city, 'Dublin')
      }.to raise_error(Dynamoid::Errors::UnknownAttribute)
    end

    describe 'callbacks' do
      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :name
          before_update { print 'run before_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attribute(:name, 'Alexey')
        end.to output('run before_update').to_stdout
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :name
          after_update { print 'run after_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attribute(:name, 'Alexey')
        end.to output('run after_update').to_stdout
      end

      it 'runs around_update callback' do
        klass_with_callback = new_class do
          field :name

          around_update :around_update_callback

          def around_update_callback
            print 'start around_update'
            yield
            print 'finish around_update'
          end
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attribute(:name, 'Alexey')
        end.to output('start around_update' + 'finish around_update').to_stdout
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name

          before_save { print 'run before_save' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attribute(:name, 'Alexey')
          end.to output('run before_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs after_save callback' do
        klass_with_callback = new_class do
          field :name

          after_save { print 'run after_save' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attribute(:name, 'Alexey')
          end.to output('run after_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs around_save callback' do
        klass_with_callback = new_class do
          field :name

          around_save :around_save_callback

          def around_save_callback
            print 'start around_save'
            yield
            print 'finish around_save'
          end
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attribute(:name, 'Alexey')
          end.to output('start around_save' + 'finish around_save').to_stdout
        }.to output.to_stdout
      end

      it 'does not run before_validation callback' do
        klass_with_callback = new_class do
          field :name

          before_validation { print 'run before_validation' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attribute(:name, 'Alexey')
          end.not_to output.to_stdout
        }.to output.to_stdout
      end

      it 'does not run after_validation callback' do
        klass_with_callback = new_class do
          field :name

          after_validation { print 'run after_validation' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attribute(:name, 'Alexey')
          end.not_to output.to_stdout
        }.to output.to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :name

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          around_save :around_save_callback

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        # print each message on new line to force RSpec to show meaningful diff
        expected_output = [
          'run before_save',
          'start around_save',
          'run before_update',
          'start around_update',
          'finish around_update',
          'run after_update',
          'finish around_save',
          'run after_save'
        ].join("\n") + "\n"

        expect { # to suppress printing at model creation
          obj = klass_with_callbacks.create(name: 'Alex')

          expect {
            obj.update_attribute(:name, 'Alexey')
          }.to output(expected_output).to_stdout
        }.to output.to_stdout
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

      it 'does not change updated_at if attributes were assigned the same values' do
        obj = klass.create(title: 'Old title', updated_at: Time.now - 1)
        obj.title = obj.title

        expect do
          obj.update_attributes(title: 'Old title')
        end.not_to change { obj.updated_at }
      end
    end

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = klass.create!(name: 'Alex', age: 26)

      expect {
        obj.update_attributes(city: 'Dublin', age: 27)
      }.to raise_error(Dynamoid::Errors::UnknownAttribute)
    end

    describe 'callbacks' do
      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :name
          before_update { print 'run before_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attributes(name: 'Alexey')
        end.to output('run before_update').to_stdout
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :name
          after_update { print 'run after_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attributes(name: 'Alexey')
        end.to output('run after_update').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :name

          before_update { print 'run before_update' }
          after_update { print 'run after_update' }

          before_save { print 'run before_save' }
          after_save { print 'run after_save' }
        end
        model = klass_with_callbacks.create(name: 'John')

        expected_output = \
          'run before_save' \
          'run before_update' \
          'run after_update' \
          'run after_save'

        expect { model.update_attributes(name: 'Mike') }.to output(expected_output).to_stdout
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

    it 'raises an UnknownAttribute error when adding an attribute that is not on the model' do
      obj = klass.create!(name: 'Alex', age: 26)

      expect {
        obj.update_attributes!(city: 'Dublin', age: 27)
      }.to raise_error(Dynamoid::Errors::UnknownAttribute)
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.update_attributes!(tags: [])
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attributes!(name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
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

      it 'does not change updated_at if attributes were assigned the same values' do
        obj = klass.create(title: 'Old title', updated_at: Time.now - 1)
        obj.title = obj.title

        expect do
          obj.update_attributes!(title: 'Old title')
        end.not_to change { obj.updated_at }
      end
    end

    describe 'callbacks' do
      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :name
          before_update { print 'run before_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attributes!(name: 'Alexey')
        end.to output('run before_update').to_stdout
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :name
          after_update { print 'run after_update' }
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attributes!(name: 'Alexey')
        end.to output('run after_update').to_stdout
      end

      it 'runs around_update callback' do
        klass_with_callback = new_class do
          field :name

          around_update :around_update_callback

          def around_update_callback
            print 'start around_update'
            yield
            print 'finish around_update'
          end
        end

        obj = klass_with_callback.create(name: 'Alex')

        expect do
          obj.update_attributes!(name: 'Alexey')
        end.to output('start around_update' + 'finish around_update').to_stdout
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          field :name

          before_save { print 'run before_save' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attributes!(name: 'Alexey')
          end.to output('run before_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs after_save callback' do
        klass_with_callback = new_class do
          field :name

          after_save { print 'run after_save' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attributes!(name: 'Alexey')
          end.to output('run after_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs around_save callback' do
        klass_with_callback = new_class do
          field :name

          around_save :around_save_callback

          def around_save_callback
            print 'start around_save'
            yield
            print 'finish around_save'
          end
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attributes!(name: 'Alexey')
          end.to output('start around_save' + 'finish around_save').to_stdout
        }.to output.to_stdout
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          field :name

          before_validation { print 'run before_validation' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attributes!(name: 'Alexey')
          end.to output('run before_validation').to_stdout
        }.to output.to_stdout
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          field :name

          after_validation { print 'run after_validation' }
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callback.create(name: 'Alex')

          expect do
            obj.update_attributes!(name: 'Alexey')
          end.to output('run after_validation').to_stdout
        }.to output.to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :name

          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          around_save :around_save_callback

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        # print each message on new line to force RSpec to show meaningful diff
        expected_output = [
          'run before_validation',
          'run after_validation',
          'run before_save',
          'start around_save',
          'run before_update',
          'start around_update',
          'finish around_update',
          'run after_update',
          'finish around_save',
          'run after_save'
        ].join("\n") + "\n"

        expect { # to suppress printing at model creation
          obj = klass_with_callbacks.create(name: 'Alex')

          expect {
            obj.update_attributes!(name: 'Alexey')
          }.to output(expected_output).to_stdout
        }.to output.to_stdout
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
      obj = document_class.create(age: 21)

      expect { obj.increment!(:age) }.to change { obj.age }.from(21).to(22)
    end

    it 'initializes the attribute with zero if it == nil' do
      obj = document_class.create(age: nil)

      expect { obj.increment!(:age) }.to change { obj.age }.from(nil).to(1)
    end

    it 'adds specified optional value' do
      obj = document_class.create(age: 21)

      expect { obj.increment!(:age, 10) }.to change { obj.age }.from(21).to(31)
    end

    it 'persists the attribute new value' do
      obj = document_class.create(age: 21)
      obj.increment!(:age, 10)
      obj_loaded = document_class.find(obj.id)

      expect(obj_loaded.age).to eq 31
    end

    it 'does not persist other changed attributes' do
      klass = new_class do
        field :age, :integer
        field :title
      end

      obj = klass.create!(age: 21, title: 'title')
      obj.title = 'new title'
      obj.increment!(:age)

      obj_loaded = klass.find(obj.id)
      expect(obj_loaded.title).to eq 'title'
    end

    it 'does not restore other changed attributes persisted values' do
      klass = new_class do
        field :age, :integer
        field :title
      end

      obj = klass.create!(age: 21, title: 'title')
      obj.title = 'new title'
      obj.increment!(:age)

      expect(obj.title).to eq 'new title'
      expect(obj.title_changed?).to eq true
    end

    it 'returns self' do
      obj = document_class.create(age: 21)
      expect(obj.increment!(:age, 10)).to eq obj
    end

    it 'marks the attribute as not changed' do
      obj = document_class.create(age: 21)
      obj.increment!(:age, 10)

      expect(obj.age_changed?).to eq false
    end

    it 'skips validation' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { less_than: 16 }
      end

      obj = class_with_validation.create(age: 10)
      obj.increment!(:age, 7)
      expect(obj.valid?).to eq false

      obj_loaded = class_with_validation.find(obj.id)
      expect(obj_loaded.age).to eq 17
    end

    it 'skips callbacks' do
      klass = new_class do
        field :age, :integer
        field :title

        before_save :before_save_callback

        def before_save_callback; end
      end

      obj = klass.new(age: 21)

      expect(obj).to receive(:before_save_callback)
      obj.save!

      expect(obj).not_to receive(:before_save_callback)
      obj.increment!(:age, 10)
    end

    it 'works well if there is a sort key' do
      klass_with_sort_key = new_class do
        range :name
        field :age, :integer
      end

      obj = klass_with_sort_key.create(name: 'Alex', age: 21)
      obj.increment!(:age, 10)
      obj_loaded = klass_with_sort_key.find(obj.id, range_key: obj.name)

      expect(obj_loaded.age).to eq 31
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create(age: 21, updated_at: Time.now - 1.day)

      expect { obj.increment!(:age) }.not_to change { document_class.find(obj.id).updated_at }
      expect { obj.increment!(:age, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    context 'when :touch option passed' do
      it 'updates `updated_at` and the specified attributes when touch: [<name>*] option passed' do
        klass = new_class do
          field :age, :integer
          field :viewed_at, :datetime
        end

        obj = klass.create(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

        expect do
          expect do
            obj.increment!(:age, touch: [:viewed_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end

      it 'runs after_touch callback' do
        klass_with_callback = new_class do
          field :age, :integer
          after_touch { print 'run after_touch' }
        end

        obj = klass_with_callback.create

        expect { obj.increment!(:age, touch: true) }.to output('run after_touch').to_stdout
      end
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

  describe '#decrement!' do
    let(:document_class) do
      new_class do
        field :age, :integer
      end
    end

    it 'decrements specified attribute' do
      obj = document_class.create(age: 21)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(21).to(20)
    end

    it 'initializes the attribute with zero if nil' do
      obj = document_class.create(age: nil)

      expect { obj.decrement!(:age) }.to change { obj.age }.from(nil).to(-1)
    end

    it 'adds specified optional value' do
      obj = document_class.create(age: 21)

      expect { obj.decrement!(:age, 10) }.to change { obj.age }.from(21).to(11)
    end

    it 'persists the attribute new value' do
      obj = document_class.create(age: 21)
      obj.decrement!(:age, 10)
      obj_loaded = document_class.find(obj.id)

      expect(obj_loaded.age).to eq 11
    end

    it 'does not persist other changed attributes' do
      klass = new_class do
        field :age, :integer
        field :title
      end

      obj = klass.create!(age: 21, title: 'title')
      obj.title = 'new title'
      obj.decrement!(:age)

      obj_loaded = klass.find(obj.id)
      expect(obj_loaded.title).to eq 'title'
    end

    it 'does not restore other changed attributes persisted values' do
      klass = new_class do
        field :age, :integer
        field :title
      end

      obj = klass.create!(age: 21, title: 'title')
      obj.title = 'new title'
      obj.decrement!(:age)

      expect(obj.title).to eq 'new title'
      expect(obj.title_changed?).to eq true
    end

    it 'returns self' do
      obj = document_class.create(age: 21)
      expect(obj.decrement!(:age, 10)).to eq obj
    end

    it 'marks the attribute as not changed' do
      obj = document_class.create(age: 21)
      obj.decrement!(:age, 10)

      expect(obj.age_changed?).to eq false
    end

    it 'skips validation' do
      class_with_validation = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 16 }
      end

      obj = class_with_validation.create!(age: 20)
      obj.decrement!(:age, 7)
      expect(obj.valid?).to eq false

      obj_loaded = class_with_validation.find(obj.id)
      expect(obj_loaded.age).to eq 13
    end

    it 'skips callbacks' do
      klass = new_class do
        field :age, :integer
        field :title

        before_save :before_save_callback

        def before_save_callback; end
      end

      obj = klass.new(age: 21)

      expect(obj).to receive(:before_save_callback)
      obj.save!

      expect(obj).not_to receive(:before_save_callback)
      obj.decrement!(:age, 10)
    end

    it 'works well if there is a sort key' do
      klass_with_sort_key = new_class do
        range :name
        field :age, :integer
      end

      obj = klass_with_sort_key.create(name: 'Alex', age: 21)
      obj.decrement!(:age, 10)
      obj_loaded = klass_with_sort_key.find(obj.id, range_key: obj.name)

      expect(obj_loaded.age).to eq 11
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create(age: 21, updated_at: Time.now - 1.day)

      expect { obj.decrement!(:age) }.not_to change { document_class.find(obj.id).updated_at }
      expect { obj.decrement!(:age, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    context 'when :touch option passed' do
      it 'updates `updated_at` and the specified attributes' do
        klass = new_class do
          field :age, :integer
          field :viewed_at, :datetime
        end

        obj = klass.create(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

        expect do
          expect do
            obj.decrement!(:age, touch: [:viewed_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end

      it 'runs after_touch callback' do
        klass_with_callback = new_class do
          field :age, :integer
          after_touch { print 'run after_touch' }
        end

        obj = klass_with_callback.create

        expect { obj.decrement!(:age, touch: true) }.to output('run after_touch').to_stdout
      end
    end
  end

  describe '#update!' do
    # TODO: add some specs

    it 'returns self' do
      klass = new_class do
        field :age, :integer
      end

      obj = klass.create
      result = obj.update! { |t| t.set(age: 21) }
      expect(result).to eq obj
    end

    it 'checks the conditions on update' do
      @tweet = Tweet.create!(tweet_id: 1, group: 'abc', count: 5, tags: Set.new(%w[db sql]), user_name: 'John')

      @tweet.update!(if: { count: 5 }) do |t|
        t.add(count: 3)
      end
      expect(@tweet.count).to eql 8
      expect(Tweet.find(@tweet.tweet_id, range_key: @tweet.group).count).to eql 8

      expect do
        @tweet.update!(if: { count: 5 }) do |t|
          t.add(count: 3)
        end
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.update! { |t| t.set(tags: Set.new) }
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update! { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end
  end

  describe '#update' do
    before do
      @tweet = Tweet.create(tweet_id: 1, group: 'abc', count: 5, tags: Set.new(%w[db sql]), user_name: 'John')
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

    it 'supports add/delete/set operations on a field' do
      @tweet.update do |t|
        t.add(count: 3)
        t.delete(tags: Set.new(['db']))
        t.set(user_name: 'Alex')
      end

      expect(@tweet.count).to eq(8)
      expect(@tweet.tags.to_a).to eq(['sql'])
      expect(@tweet.user_name).to eq 'Alex'
    end

    it 'checks the conditions on update' do
      expect(
        @tweet.update(if: { count: 5 }) do |t|
          t.add(count: 3)
        end
      ).to eql true
      expect(@tweet.count).to eql 8
      expect(Tweet.find(@tweet.tweet_id, range_key: @tweet.group).count).to eql 8

      expect(
        @tweet.update(if: { count: 5 }) do |t|
          t.add(count: 3)
        end
      ).to eql false
      expect(@tweet.count).to eql 8
      expect(Tweet.find(@tweet.tweet_id, range_key: @tweet.group).count).to eql 8
    end

    it 'prevents concurrent saves to tables with a lock_version' do
      address.save!
      a2 = Address.find(address.id)
      a2.update { |a| a.set(city: 'Chicago') }

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
      obj.update { |d| d.set(name: 'New value') }

      expect(obj.reload.name).to eql('New value')
    end

    it 'saves empty Set as nil' do
      klass_with_set = new_class do
        field :tags, :set
      end

      obj = klass_with_set.create!(tags: [:fishing])
      obj.update { |t| t.set(tags: Set.new) }
      obj_loaded = klass_with_set.find(obj.id)

      expect(obj_loaded.tags).to eql nil
    end

    it 'saves empty string as nil' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
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

      it 'does not set updated_at if Config.timestamps=true and table timestamps=false', config: { timestamps: true } do
        klass.table timestamps: false

        obj = klass.create(title: 'Old title')
        obj.update { |d| d.set(title: 'New title') }

        expect(obj.reload.attributes).not_to have_key(:updated_at)
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

    describe 'callbacks' do
      it 'runs before_update callback' do
        klass_with_callback = new_class do
          field :count, :integer
          before_update { print 'run before_update' }
        end
        model = klass_with_callback.create

        expect do
          model.update do |t|
            t.add(count: 3)
          end
        end.to output('run before_update').to_stdout
      end

      it 'runs after_update callback' do
        klass_with_callback = new_class do
          field :count, :integer
          before_update { print 'run after_update' }
        end
        model = klass_with_callback.create

        expect do
          model.update do |t|
            t.add(count: 3)
          end
        end.to output('run after_update').to_stdout
      end

      it 'runs around_update callback' do
        klass_with_callback = new_class do
          field :count, :integer
          around_update :around_update_callback

          def around_update_callback
            print 'start around_update'
            yield
            print 'finish around_update'
          end
        end

        model = klass_with_callback.create

        expect do
          model.update do |t|
            t.add(count: 3)
          end
        end.to output('start around_update' + 'finish around_update').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          field :count, :integer

          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          around_save :around_save_callback

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        # print each message on new line to force RSpec to show meaningful diff
        expected_output = [
          'run before_update',
          'start around_update',
          'finish around_update',
          'run after_update',
        ].join("\n") + "\n"

        expect { # to suppress printing at model creation
          model = klass_with_callbacks.create

          expect {
            model.update do |t|
              t.add(count: 3)
            end
          }.to output(expected_output).to_stdout
        }.to output.to_stdout
      end
    end
  end

  context 'destroy' do
    # TODO: adopt test cases for the `delete` method

    describe 'callbacks' do
      it 'runs before_destroy callback' do
        klass_with_callback = new_class do
          before_destroy { print 'run before_destroy' }
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('run before_destroy').to_stdout
      end

      it 'runs after_destroy callback' do
        klass_with_callback = new_class do
          after_destroy { print 'run after_destroy' }
        end

        obj = klass_with_callback.create
        expect { obj.destroy }.to output('run after_destroy').to_stdout
      end

      it 'runs around_destroy callback' do
        klass_with_callback = new_class do
          around_destroy :around_destroy_callback

          def around_destroy_callback
            print 'start around_destroy'
            yield
            print 'finish around_destroy'
          end
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('start around_destroy' + 'finish around_destroy').to_stdout
      end
    end
  end

  context 'delete' do
    it 'deletes an item' do
      klass = new_class
      obj = klass.create

      expect { obj.delete }.to change { klass.exists? obj.id }.from(true).to(false)
    end

    it 'returns self' do
      klass = new_class
      obj = klass.create

      expect(obj.delete).to eq obj
    end

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
        expect { address.destroy }.not_to raise_error
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

        expect { a1.destroy }.not_to raise_error
      end
    end

    context 'when model has associations' do
      context 'when belongs_to association' do
        context 'when has_many on the other side' do
          let!(:source_model) { User.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.delete
            end.to change { CamelCase.find(target_model.id).users.target }.from([source_model]).to([])
          end

          it 'updates cached ids list in associated model' do
            source_model.delete
            expect(CamelCase.find(target_model.id).users_ids).to eq nil
          end

          it 'behaves correctly when associated model is linked with several models' do
            source_model2 = User.create
            target_model.users << source_model2

            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
            source_model.delete
            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model2)
            expect(CamelCase.find(target_model.id).users_ids).to eq [source_model2.id].to_set
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.delete }.not_to raise_error
            expect(CamelCase.find(target_model.id).users.target).to eq []
          end
        end

        context 'when has_one on the other side' do
          let!(:source_model) { Sponsor.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.delete
            end.to change { CamelCase.find(target_model.id).sponsor.target }.from(source_model).to(nil)
          end

          it 'updates cached ids list in associated model' do
            source_model.delete
            expect(CamelCase.find(target_model.id).sponsor_ids).to eq nil
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.delete }.not_to raise_error
            expect(CamelCase.find(target_model.id).sponsor.target).to eq nil
          end
        end
      end

      context 'when has_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.books.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Magazine.find(target_model.title).owner.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Magazine.find(target_model.title).owner_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          books_ids_new = source_model.books_ids + ['fake_id']
          source_model.update_attributes!(books_ids: books_ids_new)

          expect { source_model.delete }.not_to raise_error
          expect(Magazine.find(target_model.title).owner).to eq nil
        end
      end

      context 'when has_one association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.monthly.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Subscription.find(target_model.id).customer.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Subscription.find(target_model.id).customer_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          source_model.update_attributes!(monthly_ids: ['fake_id'])

          expect { source_model.delete }.not_to raise_error
        end
      end

      context 'when has_and_belongs_to_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.subscriptions.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Subscription.find(target_model.id).users.target }.from([source_model]).to([])
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Subscription.find(target_model.id).users_ids).to eq nil
        end

        it 'behaves correctly when associated model is linked with several models' do
          source_model2 = User.create
          target_model.users << source_model2

          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
          source_model.delete
          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model2)
          expect(Subscription.find(target_model.id).users_ids).to eq [source_model2.id].to_set
        end

        it 'does not raise exception when foreign key is broken' do
          subscriptions_ids_new = source_model.subscriptions_ids + ['fake_id']
          source_model.update_attributes!(subscriptions_ids: subscriptions_ids_new)

          expect { source_model.delete }.not_to raise_error
          expect(Subscription.find(target_model.id).users_ids).to eq nil
        end
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
      end.to change(Address, :count).by(2)
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

    it 'saves empty Set as nil' do
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

    it 'marks all the attributes as not changed/dirty' do
      klass = new_class do
        field :count, :integer
      end
      klass.create_table

      objects = klass.import([{ count: '101' }])
      obj = objects[0]
      expect(obj.changed?).to eql false
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
        end.to change(Address, :count).by(2)
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

        expect(backoff_strategy).to receive(:call).twice.and_call_original
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

  describe '#touch' do
    it 'assigns updated_at attribute to current time' do
      klass = new_class
      obj = klass.create

      travel 1.hour do
        obj.touch
        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'saves updated_at attribute value' do
      klass = new_class
      obj = klass.create

      travel 1.hour do
        obj.touch

        obj_persistes = klass.find(obj.id)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'returns self' do
      klass = new_class
      obj = klass.create
      expect(obj.touch).to eq obj
    end

    it 'assigns and saves specified time' do
      klass = new_class
      obj = klass.create

      time = Time.now + 1.day
      obj.touch(time: time)

      obj_persistes = klass.find(obj.id)
      expect(obj.updated_at.to_i).to eq(time.to_i)
      expect(obj_persistes.updated_at.to_i).to eq(time.to_i)
    end

    it 'assignes and saves also specified timestamp attributes' do
      klass = new_class do
        field :tagged_at, :datetime
        field :logged_in_at, :datetime
      end
      obj = klass.create

      travel 1.hour do
        obj.touch(:tagged_at, :logged_in_at)

        obj_persistes = klass.find(obj.id)

        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)

        expect(obj.tagged_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.tagged_at.to_i).to eq(Time.now.to_i)

        expect(obj.logged_in_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.logged_in_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'does not save other changed attributes' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')
      obj.name = 'Michael'

      travel 1.hour do
        obj.touch

        obj_persisted = klass.find(obj.id)
        expect(obj_persisted.name).to eq 'Alex'
      end
    end

    it 'does not validate' do
      klass_with_validation = new_class do
        field :name
        validates :name, length: { minimum: 4 }
      end

      obj = klass_with_validation.create(name: 'Theodor')
      obj.name = 'Mo'

      travel 1.hour do
        obj.touch

        obj_persistes = klass_with_validation.find(obj.id)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'raise Dynamoid::Error when not persisted model' do
      klass = new_class
      obj = klass.new

      expect {
        obj.touch
      }.to raise_error(Dynamoid::Errors::Error, 'cannot touch on a new or destroyed record object')
    end

    describe 'callbacks' do
      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          after_touch { puts 'run after_touch' }

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callbacks.create
          expect { obj.touch }.to output("run after_touch\n").to_stdout
        }.to output.to_stdout
      end
    end
  end

  describe '#persisted?' do
    before do
      klass.create_table
    end

    let(:klass) do
      new_class
    end

    it 'returns true for saved model' do
      model = klass.create!
      expect(model.persisted?).to eq true
    end

    it 'returns false for new model' do
      model = klass.new
      expect(model.persisted?).to eq false
    end

    it 'returns false for deleted model' do
      model = klass.create!

      model.delete
      expect(model.persisted?).to eq false
    end

    it 'returns false for destroyed model' do
      model = klass.create!

      model.destroy
      expect(model.persisted?).to eq false
    end
  end
end
