# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
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

    it 'saves empty string as nil by default' do
      obj = klass.create(city: '')
      obj_loaded = klass.find(obj.id)

      expect(obj_loaded.city).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      obj = klass.create(city: '')
      obj_loaded = klass.find(obj.id)

      expect(obj_loaded.city).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      obj = klass.create(city: '')
      obj_loaded = klass.find(obj.id)

      expect(obj_loaded.city).to eql ''
      expect(raw_attributes(obj)[:city]).to eql ''
    end

    describe 'callbacks' do
      before do
        ScratchPad.clear
      end

      it 'runs before_create callback' do
        klass_with_callback = new_class do
          before_create { ScratchPad.record 'run before_create' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run before_create'
      end

      it 'runs after_create callback' do
        klass_with_callback = new_class do
          after_create { ScratchPad.record 'run after_create' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run after_create'
      end

      it 'runs around_create callback' do
        klass_with_callback = new_class do
          around_create :around_create_callback

          def around_create_callback
            ScratchPad << 'start around_create'
            yield
            ScratchPad << 'finish around_create'
          end
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql ['start around_create', 'finish around_create']
      end

      it 'runs before_save callback' do
        klass_with_callback = new_class do
          before_save { ScratchPad.record 'run before_save' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run before_save'
      end

      it 'runs after_save callbacks' do
        klass_with_callback = new_class do
          after_save { ScratchPad.record 'run after_save' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run after_save'
      end

      it 'runs around_save callback' do
        klass_with_callback = new_class do
          around_save :around_save_callback

          def around_save_callback
            ScratchPad << 'start around_save'
            yield
            ScratchPad << 'finish around_save'
          end
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql ['start around_save', 'finish around_save']
      end

      it 'runs before_validation callback' do
        klass_with_callback = new_class do
          before_validation { ScratchPad.record 'run before_validation' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run before_validation'
      end

      it 'runs after_validation callback' do
        klass_with_callback = new_class do
          after_validation { ScratchPad.record 'run after_validation' }
        end

        klass_with_callback.create!
        expect(ScratchPad.recorded).to eql 'run after_validation'
      end

      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          before_validation { ScratchPad << 'run before_validation' }
          after_validation { ScratchPad << 'run after_validation' }

          before_create { ScratchPad << 'run before_create' }
          after_create { ScratchPad << 'run after_create' }
          around_create :around_create_callback

          before_save { ScratchPad << 'run before_save' }
          after_save { ScratchPad << 'run after_save' }
          around_save :around_save_callback

          def around_create_callback
            ScratchPad << 'start around_create'
            yield
            ScratchPad << 'finish around_create'
          end

          def around_save_callback
            ScratchPad << 'start around_save'
            yield
            ScratchPad << 'finish around_save'
          end
        end

        klass_with_callbacks.create!
        expect(ScratchPad.recorded).to eql [
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
        ]
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
end
