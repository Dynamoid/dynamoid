require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Criteria::Chain do
  let(:time) { DateTime.now }
  let!(:user) { User.create(:name => 'Josh', :email => 'josh@joshsymonds.com', :password => 'Test123') }
  let(:chain) { Dynamoid::Criteria::Chain.new(User) }

  describe 'Query vs Scan' do
    it 'Scans when query is empty' do
      chain = Dynamoid::Criteria::Chain.new(Address)
      chain.query = {}
      expect(chain).to receive(:records_via_scan)
      chain.all
    end

    it 'Queries when query is only ID' do
      chain = Dynamoid::Criteria::Chain.new(Address)
      chain.query = { :id => 'test' }
      expect(chain).to receive(:records_via_query)
      chain.all
    end

    it 'Scans when query includes keys that are neither a hash nor a range' do
      chain = Dynamoid::Criteria::Chain.new(Address)
      chain.query = { :id => 'test', :city => 'Bucharest' }
      expect(chain).to receive(:records_via_scan)
      chain.all
    end

    it 'Scans when query is only a range' do
      chain = Dynamoid::Criteria::Chain.new(Tweet)
      chain.query = { :group => 'xx' }
      expect(chain).to receive(:records_via_scan)
      chain.all
    end
  end

  describe 'User' do
    let(:chain) { described_class.new(User) }

    it 'defines each' do
      chain.query = {:name => 'Josh'}
      chain.each {|u| u.update_attribute(:name, 'Justin')}

      expect(User.find(user.id).name).to eq 'Justin'
    end

    it 'includes Enumerable' do
      chain.query = {:name => 'Josh'}

      expect(chain.collect {|u| u.name}).to eq ['Josh']
    end
  end

  describe 'Tweet' do
    let!(:tweet1) { Tweet.create(:tweet_id => "x", :group => "one") }
    let!(:tweet2) { Tweet.create(:tweet_id => "x", :group => "two") }
    let!(:tweet3) { Tweet.create(:tweet_id => "xx", :group => "two") }
    let(:tweets) { [tweet1, tweet2, tweet3] }
    let(:chain) { Dynamoid::Criteria::Chain.new(Tweet) }

    it 'limits evaluated records' do
      chain.query = {}
      expect(chain.eval_limit(1).count).to eq 1
    end

    it 'finds tweets with a start' do
      chain.query = { :tweet_id => "x" }
      chain.start(tweet1)
      expect(chain.count).to eq 1
      expect(chain.first).to eq tweet2
    end

    it 'finds one specific tweet' do
      chain.query = { :tweet_id => "xx", :group => "two" }
      expect(chain.all).to eq [tweet3]
    end

    it 'finds posts with "where" method' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(:post_id => 'x', :posted_at => time)
      post2 = Post.create(:post_id => 'x', :posted_at => (time + 1.hour))
      chain = Dynamoid::Criteria::Chain.new(Post)
      query = { :post_id => "x", "posted_at.gt" => time + ts_epsilon }
      resultset = chain.send(:where, query)
      expect(resultset.count).to eq 1
      stored_record = resultset.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post2.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post2.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post2.attributes[:updated_at])
    end

    describe 'destroy' do
      it 'destroys tweet with a range simple range query' do
        chain.query = { :tweet_id => "x" }
        expect(chain.all.size).to eq 2
        chain.destroy_all
        expect(chain.consistent.all.size).to eq 0
      end

      it 'deletes one specific tweet with range' do
        chain = Dynamoid::Criteria::Chain.new(Tweet)
        chain.query = { :tweet_id => "xx", :group => "two" }
        expect(chain.all.size).to eq 1
        chain.destroy_all
        expect(chain.consistent.all.size).to eq 0
      end
    end

    describe 'batch queries' do
      it 'returns all results' do
        expect(chain.batch(2).all.count).to eq tweets.size
      end
    end
  end
end
