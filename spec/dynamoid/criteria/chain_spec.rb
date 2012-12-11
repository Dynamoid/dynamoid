require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::Chain" do

  before(:each) do
    @time = DateTime.now
    @user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com', :password => 'Test123')
    @chain = Dynamoid::Criteria::Chain.new(User)
  end

  it 'finds matching index for a query' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:index).should == User.indexes[[:name]]

    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:index).should == User.indexes[[:email]]

    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:index).should == User.indexes[[:email, :name]]
  end

  it 'finds matching index for a range query' do
    @chain.query = {"created_at.gt" => @time - 1.day}
    @chain.send(:index).should == User.indexes[[:created_at]]

    @chain.query = {:name => 'Josh', "created_at.lt" => @time - 1.day}
    @chain.send(:index).should == User.indexes[[:created_at, :name]]
  end

  it 'does not find an index if there is not an appropriate one' do
    @chain.query = {:password => 'Test123'}
    @chain.send(:index).should be_nil

    @chain.query = {:password => 'Test123', :created_at => @time}
    @chain.send(:index).should be_nil
  end

  it 'returns values for index for a query' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:index_query).should == {:hash_value => 'Josh'}

    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:index_query).should == {:hash_value => 'josh@joshsymonds.com'}

    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:index_query).should == {:hash_value => 'josh@joshsymonds.com.Josh'}

    @chain.query = {:name => 'Josh', 'created_at.gt' => @time}
    @chain.send(:index_query).should == {:hash_value => 'Josh', :range_greater_than => @time.to_f}
  end

  it 'finds records with an index' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:records_with_index).should == [@user]

    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:records_with_index).should == [@user]

    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:records_with_index).should == [@user]
  end

  it 'returns records with an index for a ranged query' do
    @chain.query = {:name => 'Josh', "created_at.gt" => @time - 1.day}
    @chain.send(:records_with_index).should == [@user]

    @chain.query = {:name => 'Josh', "created_at.lt" => @time + 1.day}
    @chain.send(:records_with_index).should == [@user]
  end

  it 'finds records without an index' do
    @chain.query = {:password => 'Test123'}
    @chain.send(:records_without_index).should == [@user]
  end

  it "doesn't crash if it finds a nil id in the index" do
    @chain.query = {:name => 'Josh', "created_at.gt" => @time - 1.day}
    Dynamoid::Adapter.expects(:query).
                      with("dynamoid_tests_index_user_created_ats_and_names", kind_of(Hash)).
                      returns([{ids: nil}, {ids: Set.new([42])}])
    @chain.send(:ids_from_index).should == Set.new([42])
  end

  it 'defines each' do
    @chain.query = {:name => 'Josh'}
    @chain.each {|u| u.update_attribute(:name, 'Justin')}

    User.find(@user.id).name.should == 'Justin'
  end

  it 'includes Enumerable' do
    @chain.query = {:name => 'Josh'}

    @chain.collect {|u| u.name}.should == ['Josh']
  end

  it 'finds range querys' do
    @chain = Dynamoid::Criteria::Chain.new(Tweet)
    @chain.query = { :tweet_id => 'test' }
    @chain.send(:range?).should be_true

    @chain.query = {:tweet_id => 'test', :group => 'xx'}
    @chain.send(:range?).should be_true

    @chain.query = { :group => 'xx' }
    @chain.send(:range?).should be_false

    @chain.query = { :group => 'xx', :msg => 'hai' }
    @chain.send(:range?).should be_false
  end

  context 'range queries' do
    before do
      @tweet1 = Tweet.create(:tweet_id => "x", :group => "one")
      @tweet2 = Tweet.create(:tweet_id => "x", :group => "two")
      @tweet3 = Tweet.create(:tweet_id => "xx", :group => "two")
      @chain = Dynamoid::Criteria::Chain.new(Tweet)
    end

    it 'finds tweets with a simple range query' do
      @chain.query = { :tweet_id => "x" }
      @chain.send(:records_with_range).size.should == 2
      @chain.all.size.should == 2
      @chain.limit(1).size.should == 1
    end

    it 'finds tweets with a start' do
      @chain.query = { :tweet_id => "x" }
      @chain.start(@tweet1)
      @chain.all.should =~ [@tweet2]
    end

    it 'finds one specific tweet' do
      @chain = Dynamoid::Criteria::Chain.new(Tweet)
      @chain.query = { :tweet_id => "xx", :group => "two" }
      @chain.send(:records_with_range).should == [@tweet3]
    end
  end
  
  context 'destroy alls' do
    before do
      @tweet1 = Tweet.create(:tweet_id => "x", :group => "one")
      @tweet2 = Tweet.create(:tweet_id => "x", :group => "two")
      @tweet3 = Tweet.create(:tweet_id => "xx", :group => "two")
      @chain = Dynamoid::Criteria::Chain.new(Tweet)
    end
    
    it 'destroys tweet with a range simple range query' do
      @chain.query = { :tweet_id => "x" }
      @chain.all.size.should == 2
      @chain.destroy_all
      @chain.consistent.all.size.should == 0
    end

    it 'deletes one specific tweet with range' do
      @chain = Dynamoid::Criteria::Chain.new(Tweet)
      @chain.query = { :tweet_id => "xx", :group => "two" }
      @chain.all.size.should == 1
      @chain.destroy_all
      @chain.consistent.all.size.should == 0
    end
  end
end
