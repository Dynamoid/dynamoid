require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Document" do

  it 'initializes a new document' do
    @address = Address.new
    
    @address.new_record.should be_true
    @address.attributes.should == {:id=>nil, :created_at=>nil, :updated_at=>nil, :city=>nil, :options=>nil, :deliverable => nil}
  end

  it 'responds to will_change! methods for all fields' do
    @address = Address.new
    @address.should respond_to(:id_will_change!)
    @address.should respond_to(:options_will_change!)
    @address.should respond_to(:created_at_will_change!)
    @address.should respond_to(:updated_at_will_change!)
  end
  
  it 'initializes a new document with attributes' do
    @address = Address.new(:city => 'Chicago')
    
    @address.new_record.should be_true
    
    @address.attributes.should == {:id=>nil, :created_at=>nil, :updated_at=>nil, :city=>"Chicago", :options=>nil, :deliverable => nil}
  end

  it 'initializes a new document with a virtual attribute' do
    @address = Address.new(:zip_code => '12345')
    
    @address.new_record.should be_true
    
    @address.attributes.should == {:id=>nil, :created_at=>nil, :updated_at=>nil, :city=>"Chicago", :options=>nil, :deliverable => nil}
  end

  it 'allows interception of write_attribute on load' do
    class Model
      include Dynamoid::Document
      field :city
      def city=(value); self[:city] = value.downcase; end
    end
    Model.new(:city => "Chicago").city.should == "chicago"
  end
  
  it 'creates a new document' do
    @address = Address.create(:city => 'Chicago')
    
    @address.new_record.should be_false
    @address.id.should_not be_nil
  end

  it 'knows if a document exists or not' do
    @address = Address.create(:city => 'Chicago')
    Address.exists?(@address.id).should be_true
    Address.exists?("does-not-exist").should be_false
  end
  
  it 'tests equivalency with itself' do
    @address = Address.create(:city => 'Chicago')
    
    @address.should == @address
  end

  it 'tests equivalency with itself when document has a range key' do
    @tweet = Tweet.create(:tweet_id => 'x', :group => 'abc')
    
    @tweet.should == @tweet
  end

  it 'is not equivalent to another document' do
    @address.should_not == Address.create
  end
  
  it 'is not equivalent to another object' do
    @address = Address.create(:city => 'Chicago')
    @address.should_not == "test"
  end

  it 'is not equivalent to another document with the same hash key but different range key' do
    tweet1 = Tweet.create(:tweet_id => 'x', :group => 'abc')
    tweet2 = Tweet.create(:tweet_id => 'x', :group => 'xyz')

    tweet1.should_not == tweet2
  end
  
  it "isn't equal to nil" do
    @address = Address.create(:city => 'Chicago')
    @address.should_not == nil
  end
  
  it 'behaves correctly when used as a key in a Hash' do
    hash = {}
    hash[Address.new(:id => '100')] = 1
    hash[Address.new(:id => '200')] = 2
    hash[Address.new(:id => '100')] = 3 # duplicate key

    hash.count.should == 2
    hash.map{ |k, v| [k.id, v] }.sort.should == [['100', 3], ['200', 2]]
  end

  it 'behaves correctly when used as a key in a Hash when the document has a range key' do
    hash = {}
    hash[Tweet.new(:tweet_id => 'x', :group => 'abc')] = 1
    hash[Tweet.new(:tweet_id => 'x', :group => 'def')] = 2
    hash[Tweet.new(:tweet_id => 'y', :group => 'def')] = 3
    hash[Tweet.new(:tweet_id => 'x', :group => 'abc')] = 4 # duplicate key

    hash.count.should == 3
    hash.map{ |k, v| [k.tweet_id, k.group, v] }.sort.should == [['x', 'abc', 4], ['x', 'def', 2], ['y', 'def', 3]]
  end

  it 'gets errors courtesy of ActiveModel' do
    @address = Address.create(:city => 'Chicago')
    
    @address.errors.should be_empty
    @address.errors.full_messages.should be_empty
  end
  
  it 'reloads itself and sees persisted changes' do
    @address = Address.create
    
    Address.first.update_attributes(:city => 'Chicago')
    
    @address.reload.city.should == 'Chicago'
  end

  it 'reloads document with range key' do
    tweet = Tweet.create(:tweet_id => 'x', :group => 'abc')
    tweet.reload.group.should == 'abc'
  end
  
  it 'has default table options' do
    @address = Address.create
    
    @address.id.should_not be_nil
    Address.table_name.should == 'dynamoid_tests_addresses'
    Address.hash_key.should == :id
    Address.read_capacity.should == 100
    Address.write_capacity.should == 20
  end
  
  it 'follows any table options provided to it' do
    @tweet = Tweet.create(:group => 12345)
    
    lambda {@tweet.id}.should raise_error(NoMethodError)
    @tweet.tweet_id.should_not be_nil
    Tweet.table_name.should == 'dynamoid_tests_twitters'
    Tweet.hash_key.should == :tweet_id
    Tweet.read_capacity.should == 200
    Tweet.write_capacity.should == 200
  end
end
