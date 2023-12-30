# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Loadable do
  describe '.reload' do
    let(:address) { Address.create }
    let(:message) { Message.create(text: 'Nice, supporting datetime range!', time: Time.now.to_datetime) }
    let(:tweet) { tweet = Tweet.create(tweet_id: 'x', group: 'abc') }

    it 'reflects persisted changes' do
      klass = new_class do
        field :city
      end

      address = klass.create(city: 'Miami')
      copy = klass.find(address.id)

      address.update_attributes(city: 'Chicago')
      expect(copy.reload.city).to eq 'Chicago'
    end

    it 'reads with strong consistency' do
      klass = new_class do
        field :message
      end

      tweet = klass.create

      expect(klass).to receive(:find).with(tweet.id, consistent_read: true).and_return(tweet)
      tweet.reload
    end

    it 'works with range key' do
      klass = new_class do
        field :message
        range :group
      end

      tweet = klass.create(group: 'tech')
      expect(tweet.reload.group).to eq 'tech'
    end

    it 'uses dumped value of sort key to load document' do
      klass = new_class do
        range :activated_on, :date
        field :name
      end

      obj = klass.create!(activated_on: Date.today, name: 'Old value')
      obj2 = klass.where(id: obj.id, activated_on: obj.activated_on).first
      obj2.update_attributes(name: 'New value')

      expect { obj.reload }.to change { obj.name }.from('Old value').to('New value')
    end

    # https://github.com/Dynamoid/dynamoid/issues/564
    it 'marks model as persisted if not saved model is already persisted and successfuly reloaded' do
      klass = new_class do
        field :message
      end

      object = klass.create(message: 'a')
      copy = klass.new(id: object.id)

      expect { copy.reload }.to change { copy.new_record? }.from(true).to(false)
      expect(copy.message).to eq 'a'
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
        end

        object = klass_with_callback.create!

        expect { object.reload }.to output('run after_initialize').to_stdout
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect { object.reload }.to output('run after_find').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect do
          object.reload
        end.to output('run after_initializerun after_find').to_stdout
      end
    end
  end
end
