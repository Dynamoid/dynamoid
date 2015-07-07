require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Criteria::Chain do
  let(:time) { DateTime.now }
  let!(:user) { User.create(:name => 'Josh', :email => 'josh@joshsymonds.com', :password => 'Test123') }
  let(:chain) { Dynamoid::Criteria::Chain.new(User) }

  it 'finds matching index for a query' do
    chain.query = {:name => 'Josh'}
    expect(chain.send(:index)).to eq User.indexes[[:name]]

    chain.query = {:email => 'josh@joshsymonds.com'}
    expect(chain.send(:index)).to eq User.indexes[[:email]]

    chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    expect(chain.send(:index)).to eq User.indexes[[:email, :name]]
  end

  it 'makes string symbol for query keys' do
    chain.query = {'name' => 'Josh'}
    expect(chain.send(:index)).to eq User.indexes[[:name]]
  end

  it 'finds matching index for a range query' do
    chain.query = {"created_at.gt" => time - 1.day}
    expect(chain.send(:index)).to eq User.indexes[[:created_at]]

    chain.query = {:name => 'Josh', "created_at.lt" => time - 1.day}
    expect(chain.send(:index)).to eq User.indexes[[:created_at, :name]]
  end

  it 'does not find an index if there is not an appropriate one' do
    chain.query = {:password => 'Test123'}
    expect(chain.send(:index)).to be_nil

    chain.query = {:password => 'Test123', :created_at => time}
    expect(chain.send(:index)).to be_nil
  end

  it 'returns values for index for a query' do
    chain.query = {:name => 'Josh'}
    expect(chain.send(:index_query)).to eq({:hash_value => 'Josh'})

    chain.query = {:email => 'josh@joshsymonds.com'}
    expect(chain.send(:index_query)).to eq({:hash_value => 'josh@joshsymonds.com'})

    chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    expect(chain.send(:index_query)).to eq({:hash_value => 'josh@joshsymonds.com.Josh'})

    chain.query = {:name => 'Josh', 'created_at.gt' => time}
    expect(chain.send(:index_query)).to eq({:hash_value => 'Josh', :range_greater_than => time.to_f})
  end

  it 'finds records with an index' do
    chain.query = {:name => 'Josh'}
    expect(chain.send(:records_with_index)).to eq user

    chain.query = {:email => 'josh@joshsymonds.com'}
    expect(chain.send(:records_with_index)).to eq user

    chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    expect(chain.send(:records_with_index)).to eq user
  end

  it 'returns records with an index for a ranged query' do
    chain.query = {:name => 'Josh', "created_at.gt" => time - 1.day}
    expect(chain.send(:records_with_index)).to eq user

    chain.query = {:name => 'Josh', "created_at.lt" => time + 1.day}
    expect(chain.send(:records_with_index)).to eq user
  end

  it 'finds records without an index' do
    chain.query = {:password => 'Test123'}
    expect(chain.send(:records_without_index).to_a).to eq [user]
  end

  it "doesn't crash if it finds a nil id in the index" do
    chain.query = {:name => 'Josh', "created_at.gt" => time - 1.day}
    expect(Dynamoid::Adapter).to receive(:query).
                      with("dynamoid_tests_index_user_created_ats_and_names", kind_of(Hash)).and_return([{ids: nil}, {ids: Set.new([42])}])
    expect(chain.send(:ids_from_index)).to eq Set.new([42])
  end

  it 'defines each' do
    chain.query = {:name => 'Josh'}
    chain.each {|u| u.update_attribute(:name, 'Justin')}

    expect(User.find(user.id).name).to eq 'Justin'
  end

  it 'includes Enumerable' do
    chain.query = {:name => 'Josh'}

    expect(chain.collect {|u| u.name}).to eq ['Josh']
  end

  it 'uses a range query when only a hash key or range key is specified in query' do
    # Primary key is [hash_key].
    chain = Dynamoid::Criteria::Chain.new(Address)
    chain.query = {}
    expect(chain.send(:range?)).to be_falsey

    chain = Dynamoid::Criteria::Chain.new(Address)
    chain.query = { :id => 'test' }
    expect(chain.send(:range?)).to be_truthy

    chain = Dynamoid::Criteria::Chain.new(Address)
    chain.query = { :id => 'test', :city => 'Bucharest' }
    expect(chain.send(:range?)).to be_falsey

    # Primary key is [hash_key, range_key].
    chain = Dynamoid::Criteria::Chain.new(Tweet)
    chain.query = { }
    expect(chain.send(:range?)).to be_falsey

    chain = Dynamoid::Criteria::Chain.new(Tweet)
    chain.query = { :tweet_id => 'test' }
    expect(chain.send(:range?)).to be_truthy

    chain.query = {:tweet_id => 'test', :msg => 'hai'}
    expect(chain.send(:range?)).to be_falsey

    chain.query = {:tweet_id => 'test', :group => 'xx'}
    expect(chain.send(:range?)).to be_truthy

    chain.query = {:tweet_id => 'test', :group => 'xx', :msg => 'hai'}
    expect(chain.send(:range?)).to be_falsey

    chain.query = { :group => 'xx' }
    expect(chain.send(:range?)).to be_falsey

    chain.query = { :group => 'xx', :msg => 'hai' }
    expect(chain.send(:range?)).to be_falsey
  end

  context 'range queries' do
    let!(:tweet1) {Tweet.create(:tweet_id => "x", :group => "one")}
    let!(:tweet2) {Tweet.create(:tweet_id => "x", :group => "two")}
    let!(:tweet3) {Tweet.create(:tweet_id => "xx", :group => "two")}
    let(:chain) { Dynamoid::Criteria::Chain.new(Tweet) }

    it 'finds tweets with a simple range query' do
      chain.query = { :tweet_id => "x" }
      expect(chain.send(:records_with_range).to_a.size).to eq 2
      expect(chain.all.size).to eq 2
      expect(chain.limit(1).size).to eq 1
    end

    it 'finds tweets with a start' do
      chain.query = { :tweet_id => "x" }
      chain.start(tweet1)
      expect(chain.count).to eq 1
      expect(chain.first).to eq tweet2
    end

    it 'finds one specific tweet' do
      chain = Dynamoid::Criteria::Chain.new(Tweet)
      chain.query = { :tweet_id => "xx", :group => "two" }
      expect(chain.send(:records_with_range).to_a).to eq [tweet3]
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
  end
  
  context 'destroy alls' do
    let!(:tweet1) {Tweet.create(:tweet_id => "x", :group => "one")}
    let!(:tweet2) {Tweet.create(:tweet_id => "x", :group => "two")}
    let!(:tweet3) {Tweet.create(:tweet_id => "xx", :group => "two")}
    let(:chain) { Dynamoid::Criteria::Chain.new(Tweet) }

    it 'destroys tweet with a range simple range query' do
      chain.query = { :tweet_id => "x" }
      expect(chain.all.size).to eq 2
      chain.destroy_all
      expect(chain.consistent.all.size).to eq 0
    end

    it 'deletes one specific tweet with range' do
      chain.query = { :tweet_id => "xx", :group => "two" }
      expect(chain.all.size).to eq 1
      chain.destroy_all
      expect(chain.consistent.all.size).to eq 0
    end
  end

  context 'batch queries' do
    let!(:tweets) { (1..4).map{|count| Tweet.create(:tweet_id => count.to_s, :group => (count % 2).to_s)} }
    let(:chain) { Dynamoid::Criteria::Chain.new(Tweet) }

    it 'returns all results' do
      expect(chain.batch(2).all.to_a.size).to eq tweets.size
    end

    it 'throws exception if partitioning is used with batching' do
      previous_value = Dynamoid::Config.partitioning
      Dynamoid::Config.partitioning = true
      expect { chain.batch(2) }.to raise_error
      Dynamoid::Config.partitioning = previous_value
    end
  end
end
