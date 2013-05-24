require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Criteria" do
  before(:all) do
    Magazine.create_table
  end
  
  before do
    @user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
    @user2 = User.create(:name => 'Justin', :email => 'justin@joshsymonds.com')
  end
  
  it 'finds first using where' do
    User.where(:name => 'Josh').first.should == @user1
  end
  
  it 'finds all using where' do
    User.where(:name => 'Josh').all.should == [@user1]
  end
  
  it 'returns all records' do
    User.all.should =~ [@user1, @user2]
    User.all.first.new_record.should be_false
  end
  
  it 'returns empty attributes for where' do
    Magazine.where(:name => 'Josh').all.should == []
  end
  
  it 'returns empty attributes for all' do
    Magazine.all.should == []
  end
  
  it 'passes each to all members' do
    User.each do |u|
      u.id.should == @user1.id || @user2.id
      u.new_record.should be_false
    end
  end

  it 'returns n records' do
    User.limit(1).size.should eq(1)
    5.times { |i| User.create(:name => 'Josh', :email => 'josh_#{i}@joshsymonds.com') }
    User.where(:name => 'Josh').all.size.should == 6
    User.where(:name => 'Josh').limit(2).size.should == 2
  end

  # TODO This test is broken using the AWS SDK adapter.
  #it 'start with a record' do
  #  5.times { |i| User.create(:name => 'Josh', :email => 'josh_#{i}@joshsymonds.com') }
  #  all = User.all
  #  User.start(all[3]).all.should eq(all[4..-1])
  #
  #  all = User.where(:name => 'Josh').all
  #  User.where(:name => 'Josh').start(all[3]).all.should eq(all[4..-1])
  #end

  it 'send consistent option to adapter' do
    Dynamoid::Adapter.expects(:get_item).with { |table_name, key, options| options[:consistent_read] == true }
    User.where(:name => 'x').consistent.first

    Dynamoid::Adapter.expects(:query).with { |table_name, options| options[:consistent_read] == true }.returns([])
    Tweet.where(:tweet_id => 'xx', :group => 'two').consistent.all

    Dynamoid::Adapter.expects(:query).with { |table_name, options| options[:consistent_read] == false }.returns([])
    Tweet.where(:tweet_id => 'xx', :group => 'two').all
  end

  it 'raises exception when consistent_read is used with scan' do
    expect do
      User.where(:password => 'password').consistent.first
    end.to raise_error(Dynamoid::Errors::InvalidQuery)
  end
    
end
