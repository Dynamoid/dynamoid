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

    it 'Queries when query contains ID' do
      chain = Dynamoid::Criteria::Chain.new(Address)
      chain.query = { :id => 'test', city: 'Bucharest' }
      expect(chain).to receive(:records_via_query)
      chain.all
    end

    it 'Scans when query includes keys that are neither a hash nor a range' do
      chain = Dynamoid::Criteria::Chain.new(Address)
      chain.query = { :city => 'Bucharest' }
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

  describe 'Query with keys conditions' do
    let(:model) {
      Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :age, :integer
      end
    }

    it 'supports eq' do
      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 30)

      expect(model.where(name: 'Bob', age: '10').all).to contain_exactly(customer1)
    end

    it 'supports lt' do
      customer1 = model.create(name: 'Bob', age: 5)
      customer2 = model.create(name: 'Bob', age: 9)
      customer3 = model.create(name: 'Bob', age: 12)

      expect(model.where(name: 'Bob', 'age.lt' => 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gt' do
      customer1 = model.create(name: 'Bob', age: 11)
      customer2 = model.create(name: 'Bob', age: 12)
      customer3 = model.create(name: 'Bob', age: 9)

      expect(model.where(name: 'Bob', 'age.gt' => 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports lte' do
      customer1 = model.create(name: 'Bob', age: 5)
      customer2 = model.create(name: 'Bob', age: 9)
      customer3 = model.create(name: 'Bob', age: 12)

      expect(model.where(name: 'Bob', 'age.lte' => 9).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gte' do
      customer1 = model.create(name: 'Bob', age: 11)
      customer2 = model.create(name: 'Bob', age: 12)
      customer3 = model.create(name: 'Bob', age: 9)

      expect(model.where(name: 'Bob', 'age.gte' => 11).all).to contain_exactly(customer1, customer2)
    end

    it 'supports begins_with' do
      model = Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :job_title, :string
      end

      customer1 = model.create(name: 'Bob', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'Bob', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'Bob', job_title: 'Creative Consultant')

      expect(model.where(name: 'Bob', 'job_title.begins_with' => 'Environmental').all)
        .to contain_exactly(customer1, customer2)
    end

    it 'supports between' do
      customer1 = model.create(name: 'Bob', age: 10)
      customer2 = model.create(name: 'Bob', age: 20)
      customer3 = model.create(name: 'Bob', age: 30)
      customer4 = model.create(name: 'Bob', age: 40)

      expect(model.where(name: 'Bob', 'age.between' => [19, 31]).all).to contain_exactly(customer2, customer3)
    end
  end

  # http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LegacyConditionalParameters.QueryFilter.html?shortFooter=true
  describe 'Query with not-keys conditions' do
    let(:model) {
      Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :last_name
        field :age, :integer
      end
    }

    it 'supports eq' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 30)

      expect(model.where(name: 'a', age: '10').all).to contain_exactly(customer1)
    end

    it 'supports lt' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 5)
      customer2 = model.create(name: 'a', last_name: 'b', age: 9)
      customer3 = model.create(name: 'a', last_name: 'c', age: 12)

      expect(model.where(name: 'a', 'age.lt' => 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gt' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 11)
      customer2 = model.create(name: 'a', last_name: 'b', age: 12)
      customer3 = model.create(name: 'a', last_name: 'c', age: 9)

      expect(model.where(name: 'a', 'age.gt' => 10).all).to contain_exactly(customer1, customer2)
    end

    it 'supports lte' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 5)
      customer2 = model.create(name: 'a', last_name: 'b', age: 9)
      customer3 = model.create(name: 'a', last_name: 'c', age: 12)

      expect(model.where(name: 'a', 'age.lte' => 9).all).to contain_exactly(customer1, customer2)
    end

    it 'supports gte' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 11)
      customer2 = model.create(name: 'a', last_name: 'b', age: 12)
      customer3 = model.create(name: 'a', last_name: 'c', age: 9)

      expect(model.where(name: 'a', 'age.gte' => 11).all).to contain_exactly(customer1, customer2)
    end

    it 'supports begins_with' do
      model = Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :last_name
        field :job_title, :string
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.begins_with' => 'Environmental').all)
        .to contain_exactly(customer1, customer2)
    end

    it 'supports between' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)
      customer4 = model.create(name: 'a', last_name: 'd', age: 40)

      expect(model.where(name: 'a', 'age.between' => [19, 31]).all).to contain_exactly(customer2, customer3)
    end

    it 'supports in' do
      customer1 = model.create(name: 'a', last_name: 'a', age: 10)
      customer2 = model.create(name: 'a', last_name: 'b', age: 20)
      customer3 = model.create(name: 'a', last_name: 'c', age: 30)

      expect(model.where(name: 'a', 'age.in' => [10, 20]).all).to contain_exactly(customer1, customer2)
    end

    it 'supports contains' do
      model = Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :last_name
        field :job_title, :string
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.contains' => 'Consul').all)
        .to contain_exactly(customer1, customer3)
    end

    it 'supports not_contains' do
      model = Class.new do
        include Dynamoid::Document
        table name: :customer, key: :name
        range :last_name
        field :job_title, :string
      end

      customer1 = model.create(name: 'a', last_name: 'a', job_title: 'Environmental Air Quality Consultant')
      customer2 = model.create(name: 'a', last_name: 'b', job_title: 'Environmental Project Manager')
      customer3 = model.create(name: 'a', last_name: 'c', job_title: 'Creative Consultant')

      expect(model.where(name: 'a', 'job_title.not_contains' => 'Consul').all)
        .to contain_exactly(customer2)
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

    it 'finds posts with "where" method with "gt" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(:post_id => 'x', :posted_at => time)
      post2 = Post.create(:post_id => 'x', :posted_at => (time + 1.hour))
      chain = Dynamoid::Criteria::Chain.new(Post)
      query = { :post_id => "x", "posted_at.gt" => (time + ts_epsilon).to_f }
      resultset = chain.send(:where, query)
      expect(resultset.count).to eq 1
      stored_record = resultset.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post2.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post2.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post2.attributes[:updated_at])
    end

    it 'finds posts with "where" method with "lt" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(:post_id => 'x', :posted_at => time)
      post2 = Post.create(:post_id => 'x', :posted_at => (time + 1.hour))
      chain = Dynamoid::Criteria::Chain.new(Post)
      query = { :post_id => "x", "posted_at.lt" => (time + 1.hour - ts_epsilon).to_f }
      resultset = chain.send(:where, query)
      expect(resultset.count).to eq 1
      stored_record = resultset.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post1.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post1.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post1.attributes[:updated_at])
    end

    it 'finds posts with "where" method with "between" query' do
      ts_epsilon = 0.001 # 1 ms
      time = DateTime.now
      post1 = Post.create(:post_id => 'x', :posted_at => time)
      post2 = Post.create(:post_id => 'x', :posted_at => (time + 1.hour))
      chain = Dynamoid::Criteria::Chain.new(Post)
      query = { :post_id => "x", "posted_at.between" => [(time - ts_epsilon).to_f, (time + ts_epsilon).to_f]}
      resultset = chain.send(:where, query)
      expect(resultset.count).to eq 1
      stored_record = resultset.first
      expect(stored_record.attributes[:post_id]).to eq post2.attributes[:post_id]
      # Must use an epsilon to compare timestamps after round-trip: https://github.com/Dynamoid/Dynamoid/issues/2
      expect(stored_record.attributes[:created_at]).to be_within(ts_epsilon).of(post1.attributes[:created_at])
      expect(stored_record.attributes[:posted_at]).to be_within(ts_epsilon).of(post1.attributes[:posted_at])
      expect(stored_record.attributes[:updated_at]).to be_within(ts_epsilon).of(post1.attributes[:updated_at])
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
