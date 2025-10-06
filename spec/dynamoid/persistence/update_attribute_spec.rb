# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#update_attribute' do
    let(:klass) do
      new_class do
        field :age, :integer
      end
    end

    let(:klass_with_composite_key) do
      new_class do
        range :name
        field :age, :integer
      end
    end

    let(:klass_with_composite_key_and_custom_type) do
      new_class do
        range :tags, :serialized
        field :name
      end
    end

    it 'changes the attribute value' do
      obj = klass.create!(age: 18)

      expect { obj.update_attribute(:age, 20) }.to change { obj.age }.from(18).to(20)
    end

    it 'persists the model' do
      obj = klass.create!(age: 18)
      obj.update_attribute(:age, 20)

      expect(klass.find(obj.id).age).to eq(20)
    end

    it 'skips validation and saves not valid models' do
      klass = new_class do
        field :age, :integer
        validates :age, numericality: { greater_than: 0 }
      end

      obj = klass.create!(age: 18)
      obj.update_attribute(:age, -1)

      expect(klass.find(obj.id).age).to eq(-1)
    end

    it 'returns self' do
      obj = klass.create!(age: 18)
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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update_attribute(:name, '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
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
        obj.title = obj.title # rubocop:disable Lint/SelfAssignment

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
        end.to output('start around_updatefinish around_update').to_stdout
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
          end.to output('start around_savefinish around_save').to_stdout
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
        expected_output = [ # rubocop:disable Style/StringConcatenation
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

    context 'when a model was concurrently deleted' do
      it 'does not persist changes when simple primary key' do
        obj = klass.create!(age: 21)
        klass.find(obj.id).delete

        obj.update_attribute(:age, 42)
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.name).delete

        obj.update_attribute(:age, 42)
        expect(klass_with_composite_key.exists?(id: obj.id, name: obj.name)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], name: 'Alex')
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.update_attribute(:name, 'Michael')
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end

    context 'when table arn is specified', remove_constants: [:Payment] do
      it 'uses given table ARN in requests instead of a table name', config: { create_table_on_save: false } do
        # Create table manually because CreateTable doesn't accept ARN as a
        # table name. Add namespace to have this table removed automativally.
        table_name = :"#{Dynamoid::Config.namespace}_purchases"
        Dynamoid.adapter.create_table(table_name, :id)

        table = Dynamoid.adapter.describe_table(table_name)
        expect(table.arn).to be_present

        Payment = Class.new do # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
          include Dynamoid::Document

          table arn: table.arn
          field :comment
        end

        payment = Payment.create!

        expect {
          payment.update_attribute(:comment, 'A')
        }.to send_request_matching(:UpdateItem, { TableName: table.arn })
      end
    end
  end

  describe '#update_attribute!' do
    context 'when a callback aborts saving' do
      it 'aborts updating if callback throws :abort' do
        if ActiveSupport.version < Gem::Version.new('5.0')
          skip "Rails 4.x and below don't support aborting with `throw :abort`"
        end

        klass = new_class do
          field :name
          before_update { throw :abort }
        end

        obj = klass.create!(name: 'Alex')

        expect {
          expect {
            obj.update_attribute!(:name, 'Alex [Updated]')
          }.to raise_error(Dynamoid::Errors::RecordNotSaved)
        }.not_to change { klass.find(obj.id).name }

        expect(obj).to be_persisted
        expect(obj).to be_changed
      end
    end
  end
end
