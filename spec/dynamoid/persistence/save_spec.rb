# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.name = ''
      obj.save
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.name = ''
      obj.save
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.name = ''
      obj.save
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
    end

    it 'does not make a request to persist a model if there is no any changed attribute' do
      obj = klass.create(name: 'Alex')

      expect(Dynamoid.adapter).to receive(:update_item).and_call_original
      obj.name = 'Michael'
      obj.save

      expect(Dynamoid.adapter).not_to receive(:update_item).and_call_original
      obj.save

      expect(Dynamoid.adapter).not_to receive(:update_item)
      obj_loaded = klass.find(obj.id)
      obj_loaded.save
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

        expect { model.save }.to raise_error(Aws::DynamoDB::Errors::ResourceNotFoundException)
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

    context 'primary key dumping' do
      context 'new model' do
        it 'uses dumped value of partition key to save item' do
          klass = new_class(partition_key: { name: :published_on, type: :date }) do
            field :title
          end

          obj = klass.new(published_on: '2018-10-07'.to_date, title: 'Some title')
          obj.save
          obj_loaded = klass.find(obj.published_on)

          expect(obj_loaded.title).to eq 'Some title'
        end

        it 'uses dumped value of sort key to save item' do
          klass = new_class do
            range :published_on, :date
            field :title
          end

          obj = klass.new(published_on: '2018-02-23'.to_date, title: 'Some title')
          obj.save
          obj_loaded = klass.find(obj.id, range_key: obj.published_on)

          expect(obj_loaded.title).to eq 'Some title'
        end
      end

      context 'persised model' do
        it 'uses dumped value of partition key to save item' do
          klass = new_class(partition_key: { name: :published_on, type: :date }) do
            field :title
          end

          obj = klass.create!(published_on: '2018-10-07'.to_date, title: 'Old')
          obj.title = 'New'
          obj.save
          obj_loaded = klass.find(obj.published_on)

          expect(obj_loaded.title).to eq 'New'
        end

        it 'uses dumped value of sort key to save item' do
          klass = new_class do
            range :published_on, :date
            field :title
          end

          obj = klass.create!(published_on: '2018-02-23'.to_date, title: 'Old')
          obj.title = 'New'
          obj.save
          obj_loaded = klass.find(obj.id, range_key: obj.published_on)

          expect(obj_loaded.title).to eq 'New'
        end
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
          expect { obj.save }.to output('start around_createfinish around_create').to_stdout
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
          expected_output = [ # rubocop:disable Style/StringConcatenation
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
          expect { obj.save }.to output('start around_updatefinish around_update').to_stdout
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
          expected_output = [ # rubocop:disable Style/StringConcatenation
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
        expect { obj.save }.to output('start around_savefinish around_save').to_stdout
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
          a.save
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
          obj.title = obj.title # rubocop:disable Lint/SelfAssignment

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
        it 'keeps document attribute with nil when model is not persisted' do
          obj = klass.new(age: nil)
          obj.save

          expect(raw_attributes(obj)).to include(age: nil)
        end

        it 'keeps document attribute with nil when model is persisted' do
          obj = klass.create(age: 42)
          obj.age = nil
          obj.save

          expect(raw_attributes(obj)).to include(age: nil)
        end
      end

      context 'false', config: { store_attribute_with_nil_value: false } do
        it 'does not keep document attribute with nil when model is not persisted' do
          obj = klass.new(age: nil)
          obj.save

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end

        it 'does not keep document attribute with nil when model is persisted' do
          obj = klass.create!(age: 42)
          obj.age = nil
          obj.save

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end
      end

      context 'by default', config: { store_attribute_with_nil_value: nil } do
        it 'does not keep document attribute with nil when model is not persisted' do
          obj = klass.new(age: nil)
          obj.save

          # doesn't contain :age key
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :created_at, :updated_at)
        end

        it 'does not keep document attribute with nil when model is persisted' do
          obj = klass.create!(age: 42)
          obj.age = nil
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
end
