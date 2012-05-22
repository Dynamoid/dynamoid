require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Dynamoid::Dirty' do

  context 'changes' do
    it 'should be empty' do
      tweet = Tweet.new
      tweet.msg_changed?.should be_false
    end

    it 'should not be empty' do
      tweet = Tweet.new(:tweet_id => "1", :group => 'abc')
      tweet.changed?.should be_true
      tweet.group_was.should be_nil
    end

    it 'should be empty when loaded from database' do
      Tweet.create!(:tweet_id => "1", :group => 'abc')
      tweet = Tweet.where(:tweet_id => "1", :group => 'abc').first
      tweet.changed?.should be_false
      tweet.group = 'abc'
      tweet.reload
      tweet.changed?.should be_false
    end

    it 'track changes after saves' do
      tweet = Tweet.new(:tweet_id => "1", :group => 'abc')
      tweet.save!
      tweet.changed?.should be_false

      tweet.user_name = 'xyz'
      tweet.user_name_changed?.should be_true
      tweet.user_name_was.should be_nil
      tweet.save!

      tweet.user_name_changed?.should be_false
      tweet.user_name = 'abc'
      tweet.user_name_was.should == 'xyz'
    end

    it 'clear changes on save' do
      tweet = Tweet.new(:tweet_id => "1", :group => 'abc')
      tweet.group = 'xyz'
      tweet.group_changed?.should be_true
      tweet.save!
      tweet.group_changed?.should be_false
    end
  end
end
