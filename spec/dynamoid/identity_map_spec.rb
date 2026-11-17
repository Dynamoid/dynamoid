# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::IdentityMap, config: { identity_map: true } do
  after do
    described_class.clear
  end

  context 'with object identity' do
    it 'maintains a single object' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      tweet1 = Tweet.where(tweet_id: 'x', group: 'one').first
      expect(tweet).to equal(tweet1)
    end

    it 'updates attributes on the existing object when loaded from database again' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one', msg: 'initial')
      tweet_from_db = Tweet.from_database(tweet_id: 'x', group: 'one', msg: 'updated')

      expect(tweet_from_db).to equal(tweet)
      expect(tweet.msg).to eq('updated')
    end
  end

  context 'with cache' do
    it 'uses cache' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      expect(Dynamoid.adapter).not_to receive(:read)
      tweet1 = Tweet.find_by_id('x', range_key: 'one')
      expect(tweet).to equal(tweet1)
    end

    it 'clears cache on delete' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      tweet.delete
      expect(Tweet.find_by_id('x', range_key: 'one')).to be_nil
    end
  end

  context 'with clear' do
    it 'clears the identity map' do
      Tweet.create(tweet_id: 'x', group: 'one')
      Tweet.create(tweet_id: 'x', group: 'two')

      expect(Tweet.identity_map.size).to eq(2)
      described_class.clear
      expect(Tweet.identity_map.size).to eq(0)
    end
  end

  context 'with multiple threads' do
    it 'isolates the identity map per thread' do
      tweet = Tweet.create(tweet_id: 'x', group: 'one')
      expect(Tweet.identity_map.size).to eq(1)

      other_thread_size = nil
      other_thread_tweet = nil

      Thread.new do # rubocop:disable ThreadSafety/NewThread
        other_thread_size = Tweet.identity_map.size
        other_thread_tweet = Tweet.find_by_id('x', range_key: 'one')
      end.join

      expect(other_thread_size).to eq(0)
      expect(other_thread_tweet).not_to equal(tweet)
      expect(other_thread_tweet.tweet_id).to eq('x')
    end

    it 'clears the identity map only for the current thread' do
      Tweet.create(tweet_id: 'x', group: 'one')
      expect(Tweet.identity_map.size).to eq(1)

      Thread.new do # rubocop:disable ThreadSafety/NewThread
        Tweet.create(tweet_id: 'y', group: 'two')
        expect(Tweet.identity_map.size).to eq(1)

        described_class.clear
        expect(Tweet.identity_map.size).to eq(0)
      end.join

      expect(Tweet.identity_map.size).to eq(1)
    end
  end
end
