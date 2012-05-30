require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::IdentityMap" do
  before :each do
    Dynamoid::Config.identity_map = true
  end

  after :each do
    Dynamoid::Config.identity_map = false
  end

  context 'object identity' do
    it 'maintains a single object' do
      tweet = Tweet.create(:tweet_id => "x", :group => "one")
      tweet1 = Tweet.where(:tweet_id => "x", :group => "one").first
      tweet.should equal(tweet1)
    end
  end

  context 'cache' do
    it 'uses cache' do
      tweet = Tweet.create(:tweet_id => "x", :group => "one")
      Dynamoid::Adapter.expects(:read).never
      tweet1 = Tweet.find_by_id("x", :range_key => "one")
      tweet.should equal(tweet1)
    end

    it 'clears cache on delete' do
      tweet = Tweet.create(:tweet_id => "x", :group => "one")
      tweet.delete
      Tweet.find_by_id("x", :range_key => "one").should be_nil
    end
  end

  context 'clear' do
    it 'clears the identiy map' do
      Tweet.create(:tweet_id => "x", :group => "one")
      Tweet.create(:tweet_id => "x", :group => "two")

      Tweet.identity_map.size.should eq(2)
      Dynamoid::IdentityMap.clear
      Tweet.identity_map.size.should eq(0)
    end
  end
end
