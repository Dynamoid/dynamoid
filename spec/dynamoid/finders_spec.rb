require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Finders" do

  before do
    @address = Address.create(:city => 'Chicago')
  end

  it 'finds an existing address' do
    found = Address.find(@address.id)

    found.should == @address
    found.city.should == 'Chicago'
  end

  it 'is not a new object' do
    found = Address.find(@address.id)

    found.new_record.should_not be_true
  end

  it 'returns nil when nothing is found' do
    Address.find('1234').should be_nil
  end

  it 'finds multiple ids' do
    @address2 = Address.create(:city => 'Illinois')

    Address.find(@address.id, @address2.id).should include @address, @address2
  end

  it 'sends consistent option to the adapter' do
    Dynamoid::Adapter.expects(:get_item).with { |table_name, key, options| options[:consistent_read] == true }
    Address.find('x', :consistent_read => true)
  end

  context 'with users' do
    before do
      User.create_indexes
    end

    it 'finds using method_missing for attributes' do
      array = Address.find_by_city('Chicago')

      array.should == @address
    end

    it 'finds using method_missing for multiple attributes' do
      @user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com')

      array.should == [@user]
    end

    it 'finds using method_missing for single attributes and multiple results' do
      @user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      @user2 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name('Josh')

      array.size.should == 2
      array.should include @user1
      array.should include @user2
    end

    it 'finds using method_missing for multiple attributes and multiple results' do
      @user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      @user2 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com')

      array.size.should == 2
      array.should include @user1
      array.should include @user2
    end

    it 'finds using method_missing for multiple attributes and no results' do
      @user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      @user2 = User.create(:name => 'Justin', :email => 'justin@joshsymonds.com')

      array = User.find_all_by_name_and_email('Gaga','josh@joshsymonds.com')

      array.should be_empty
    end

    it 'finds using method_missing for a single attribute and no results' do
      @user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      @user2 = User.create(:name => 'Justin', :email => 'justin@joshsymonds.com')

      array = User.find_all_by_name('Gaga')

      array.should be_empty
    end

    it 'should find on a query that is not indexed' do
      @user = User.create(:password => 'Test')

      array = User.find_all_by_password('Test')

      array.should == [@user]
    end

    it 'should find on a query on multiple attributes that are not indexed' do
      @user = User.create(:password => 'Test', :name => 'Josh')

      array = User.find_all_by_password_and_name('Test', 'Josh')

      array.should == [@user]
    end

    it 'should return an empty array when fields exist but nothing is found' do
      array = User.find_all_by_password('Test')

      array.should be_empty
    end

  end

  context 'find_all' do
    it 'should return a array of users' do
      users = (1..10).map { User.create }
      User.find_all(users.map(&:id)).should eq(users)
    end

    it 'should return a array of tweets' do
      tweets = (1..10).map { |i| Tweet.create(:tweet_id => "#{i}", :group => "group_#{i}") }
      Tweet.find_all(tweets.map { |t| [t.tweet_id, t.group] }).should eq(tweets)
    end

    it 'should return an empty array' do
      User.find_all([]).should eq([])
    end
  end
end
