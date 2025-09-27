# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
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

    it 'saves empty string as nil by default' do
      users = User.import([{ name: '' }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'saves empty string as nil if store_empty_string_as_nil config option is true', config: { store_empty_string_as_nil: true } do
      users = User.import([{ name: '' }])

      user = User.find(users[0].id)
      expect(user.name).to eq nil
    end

    it 'saves empty string as is if store_empty_string_as_nil config option is false', config: { store_empty_string_as_nil: false } do
      users = User.import([{ name: '' }])

      user = User.find(users[0].id)
      expect(user.name).to eq ''
      expect(raw_attributes(user)[:name]).to eql ''
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

        expect {
          Payment.import([{ comment: 'A' }, { comment: 'B' }])
        }.to send_request_matching(:BatchWriteItem, { RequestItems: { table.arn => anything } })
      end
    end
  end
end
