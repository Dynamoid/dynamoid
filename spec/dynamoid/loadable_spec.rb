# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Loadable do

  context '.reload' do
    let(:address) { Address.create }
    let(:message) { Message.create(text: 'Nice, supporting datetime range!', time: Time.now.to_datetime) }
    let(:tweet) { tweet = Tweet.create(tweet_id: 'x', group: 'abc') }

    it 'reflects persisted changes' do
      address.update_attributes(city: 'Chicago')
      expect(address.reload.city).to eq 'Chicago'
    end

    it 'uses a :consistent_read' do
      expect(Tweet).to receive(:find).with(tweet.hash_key, range_key: tweet.range_value, consistent_read: true).and_return(tweet)
      tweet.reload
    end

    it 'works with range key' do
      expect(tweet.reload.group).to eq 'abc'
    end

    it 'uses dumped value of sort key to load document' do
      klass = new_class do
        range :activated_on, :date
        field :name
      end

      obj = klass.create!(activated_on: Date.today, name: 'Old value')
      obj2 = klass.where(id: obj.id, activated_on: obj.activated_on).first
      obj2.update_attributes(name: 'New value')

      expect { obj.reload }.to change {
        obj.name
      }.from('Old value').to('New value')
    end
  end
end
