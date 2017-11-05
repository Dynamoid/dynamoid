require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Dirty do

  context 'changes' do
    it 'is empty' do
      tweet = Tweet.new
      expect(tweet.msg_changed?).to be_falsey
    end

    it 'is not empty' do
      tweet = Tweet.new(:tweet_id => '1', :group => 'abc')
      expect(tweet).to be_changed
      expect(tweet.group_was).to be_nil
    end

    it 'is empty when loaded from database' do
      Tweet.create!(:tweet_id => '1', :group => 'abc')
      tweet = Tweet.where(:tweet_id => '1', :group => 'abc').first
      expect(tweet).to_not be_changed
      tweet.group = 'abc'
      tweet.reload
      expect(tweet).to_not be_changed
    end

    it 'is empty after an update' do
      tweet = Tweet.create!(:tweet_id => '1', :group => 'abc')
      tweet.update! do |t|
        t.set(msg: 'foo')
      end
      expect(tweet).to_not be_changed
    end

    it 'tracks changes after saves' do
      tweet = Tweet.new(:tweet_id => '1', :group => 'abc')
      tweet.save!
      expect(tweet).to_not be_changed

      tweet.user_name = 'xyz'
      expect(tweet.user_name_changed?).to be_truthy
      expect(tweet.user_name_was).to be_nil
      tweet.save!

      expect(tweet.user_name_changed?).to be_falsey
      tweet.user_name = 'abc'
      expect(tweet.user_name_was).to eq 'xyz'
    end

    it 'clears changes on save' do
      tweet = Tweet.new(:tweet_id => '1', :group => 'abc')
      tweet.group = 'xyz'
      expect(tweet.group_changed?).to be_truthy
      tweet.save!
      expect(tweet.group_changed?).to be_falsey
    end
  end
end
