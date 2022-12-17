# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::IdentityMap do
  before do
    Dynamoid::Config.identity_map = true
  end

  after do
    Dynamoid::Config.identity_map = false
  end

  context 'object identity' do
    it 'maintains a single object' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      tweet1 = Tweet.where(tweet_id: 'x', group: 'one').first
      expect(tweet).to equal(tweet1)
    end
  end

  context 'cache' do
    it 'uses cache' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      expect(Dynamoid::Adapter).not_to receive(:read)
      tweet1 = Tweet.find_by_id('x', range_key: 'one')
      expect(tweet).to equal(tweet1)
    end

    it 'clears cache on delete' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      tweet.delete
      expect(Tweet.find_by_id('x', range_key: 'one')).to be nil
    end
  end

  context 'clear' do
    it 'clears the identiy map' do
      Tweet.create(tweet_id: 'x', group: 'one')
      Tweet.create(tweet_id: 'x', group: 'two')

      expect(Tweet.identity_map.size).to eq(2)
      described_class.clear
      expect(Tweet.identity_map.size).to eq(0)
    end
  end
end
