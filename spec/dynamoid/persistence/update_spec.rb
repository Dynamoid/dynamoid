# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update!(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update!(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update!(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
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
        end.to output('start around_updatefinish around_update').to_stdout
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
          end.to output('start around_savefinish around_save').to_stdout
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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'alex')
      klass_with_string.update(obj.id, name: '')
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update! { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update! { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update! { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
    end

    context 'when a model was concurrently deleted' do
      let(:klass) do
        new_class do
          field :name
          field :age, :integer
        end
      end

      let(:klass_with_composite_key) do
        new_class do
          range :age, :integer
          field :name
        end
      end

      let(:klass_with_composite_key_and_custom_type) do
        new_class do
          range :tags, :serialized
          field :name
        end
      end

      it 'does not persist changes when simple primary key' do
        obj = klass.create!(age: 21)
        klass.find(obj.id).delete

        expect {
          obj.update! { |t| t.set(age: 42) }
        }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.age).delete

        expect {
          obj.update! { |t| t.set(name: 'Michael') }
        }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], name: 'Alex')
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        expect {
          obj.update! { |t| t.set(name: 'Michael') }
        }.to raise_error(Dynamoid::Errors::StaleObjectError)
      end
    end
  end

  describe '#update' do
    it 'supports add/delete/set operations on a field' do
      @tweet = Tweet.create(tweet_id: 1, group: 'abc', count: 5, tags: Set.new(%w[db sql]), user_name: 'John')

      @tweet.update do |t|
        t.add(count: 3)
        t.delete(tags: Set.new(['db']))
        t.set(user_name: 'Alex')
      end

      expect(@tweet.count).to eq(8)
      expect(@tweet.tags.to_a).to eq(['sql'])
      expect(@tweet.user_name).to eq 'Alex'
    end

    context 'condition specified' do
      let(:document_class) do
        new_class do
          field :title
          field :version, :integer
          field :published_on, :date
        end
      end

      describe 'if condition' do
        it 'updates when model matches conditions' do
          obj = document_class.create(title: 'Old title', version: 1)

          expect {
            obj.update(if: { version: 1 }) { |t| t.set(title: 'New title') }
          }.to change { document_class.find(obj.id).title }.to('New title')
        end

        it 'returns true when model matches conditions' do
          obj = document_class.create(title: 'Old title', version: 1)

          result = obj.update(if: { version: 1 }) { |t| t.set(title: 'New title') }
          expect(result).to eq true
        end

        it 'does not update when model does not match conditions' do
          obj = document_class.create(title: 'Old title', version: 1)

          expect {
            obj.update(if: { version: 6 }) { |t| t.set(title: 'New title') }
          }.not_to change { document_class.find(obj.id).title }
        end

        it 'returns false when model does not match conditions' do
          obj = document_class.create(title: 'Old title', version: 1)

          result = obj.update(if: { version: 6 }) { |t| t.set(title: 'New title') }
          expect(result).to eq false
        end
      end

      describe 'unless_exists condition' do
        it 'updates when item does not have specified attribute' do
          # not specifying field value means (by default) the attribute will be
          # skipped and not persisted in DynamoDB
          obj = document_class.create(title: 'Old title')
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :created_at, :updated_at)

          expect {
            obj.update(unless_exists: [:version]) { |t| t.set(title: 'New title') }
          }.to change { document_class.find(obj.id).title }.to('New title')
        end

        it 'does not update when model has specified attribute' do
          obj = document_class.create(title: 'Old title', version: 1)
          expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

          expect {
            obj.update(unless_exists: [:version]) { |t| t.set(title: 'New title') }
          }.not_to change { document_class.find(obj.id).title }
        end

        context 'when multiple attribute names' do
          it 'updates when item does not have all the specified attributes' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = document_class.create(title: 'Old title')
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :created_at, :updated_at)

            expect {
              obj.update(unless_exists: %i[version published_on]) { |t| t.set(title: 'New title') }
            }.to change { document_class.find(obj.id).title }.to('New title')
          end

          it 'does not update when model has all the specified attributes' do
            obj = document_class.create(title: 'Old title', version: 1, published_on: '2018-02-23'.to_date)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :published_on, :created_at, :updated_at)

            expect {
              obj.update(unless_exists: %i[version published_on]) { |t| t.set(title: 'New title') }
            }.not_to change { document_class.find(obj.id).title }
          end

          it 'does not update when model has at least one specified attribute' do
            # not specifying field value means (by default) the attribute will be
            # skipped and not persisted in DynamoDB
            obj = document_class.create(title: 'Old title', version: 1)
            expect(raw_attributes(obj).keys).to contain_exactly(:id, :title, :version, :created_at, :updated_at)

            expect {
              obj.update(unless_exists: %i[version published_on]) { |t| t.set(title: 'New title') }
            }.not_to change { document_class.find(obj.id).title }
          end
        end
      end
    end

    it 'prevents concurrent saves to tables with a lock_version' do
      address = Address.create!
      a2 = Address.find(address.id)
      a2.update { |a| a.set(city: 'Chicago') }

      expect do
        address.city = 'Seattle'
        address.save!
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'uses dumped value of partition key to update item' do
      klass = new_class(partition_key: { name: :published_on, type: :date }) do
        field :name
      end

      obj = klass.create!(published_on: '2018-10-07'.to_date, name: 'Old')
      obj.update { |d| d.set(name: 'New') }

      expect(obj.reload.name).to eql('New')
    end

    it 'uses dumped value of sort key to update item' do
      klass = new_class do
        range :activated_on, :date
        field :name
      end

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

    it 'saves empty string as nil by default' do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      klass_with_string = new_class do
        field :name
      end

      obj = klass_with_string.create!(name: 'Alex')
      obj.update { |t| t.set(name: '') }
      obj_loaded = klass_with_string.find(obj.id)

      expect(obj_loaded.name).to eql ''
      expect(raw_attributes(obj)[:name]).to eql ''
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
        end.to output('start around_updatefinish around_update').to_stdout
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
        expected_output = [ # rubocop:disable Style/StringConcatenation
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

    context 'when a model was concurrently deleted' do
      let(:klass) do
        new_class do
          field :name
          field :age, :integer
        end
      end

      let(:klass_with_composite_key) do
        new_class do
          range :age, :integer
          field :name
        end
      end

      let(:klass_with_composite_key_and_custom_type) do
        new_class do
          range :tags, :serialized
          field :name
        end
      end

      it 'does not persist changes when simple primary key' do
        obj = klass.create!(age: 21)
        klass.find(obj.id).delete

        obj.update { |t| t.set(age: 42) }
        expect(klass.exists?(obj.id)).to eql(false)
      end

      it 'does not persist changes when composite primary key' do
        obj = klass_with_composite_key.create!(name: 'Alex', age: 21)
        klass_with_composite_key.find(obj.id, range_key: obj.age).delete

        obj.update { |t| t.set(name: 'Michael') }
        expect(klass_with_composite_key.exists?(id: obj.id, age: obj.age)).to eql(false)
      end

      it 'does not persist changes when composite primary key and sort key type is not supported by DynamoDB natively' do
        obj = klass_with_composite_key_and_custom_type.create!(tags: %w[a b], name: 'Alex')
        klass_with_composite_key_and_custom_type.find(obj.id, range_key: obj.tags).delete

        obj.update { |t| t.set(name: 'Michael') }
        expect(klass_with_composite_key_and_custom_type.exists?(id: obj.id, tags: obj.tags)).to eql(false)
      end
    end
  end
end
