require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Indexes" do
  
  before do
    User.create_indexes
  end

  it 'raises an error if a field does not exist' do
    lambda {User.send(:index, :test)}.should raise_error(Dynamoid::Errors::InvalidField)
  end
  
  it 'adds indexes to the index array' do
    User.indexes.should == [[:name], [:email], [:email, :name]]
  end
  
  it 'reorders index names alphabetically' do
    User.indexes.last.should == [:email, :name]
  end
  
  it 'creates a name for a table index' do
    User.index_table_name([:email, :name]).should == 'dynamoid_tests_index_user_emails_and_names'
  end
  
  it 'creates a key name for a table index' do
    User.index_key_name([:email, :name]).should == 'user_emails_and_names'
  end
  
  it 'creates a table after an index is created' do
    User.send(:index, :password)
    
    User.table_exists?(User.index_table_name([:password])).should be_true
  end
  
  it 'assembles a hashed value for the key of an index' do
    @user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
    
    @user.key_for_index([:email, :name]).should == (Digest::SHA2.new << 'Josh' << 'josh@joshsymonds.com').to_s
  end
  
  it 'saves indexes to their tables' do
    @user = User.create(:name => 'Josh')
    
    Dynamoid::Adapter.get_item("dynamoid_tests_index_user_names", @user.key_for_index([:name])).should == {@user.class.index_key_name([:name]).to_sym => @user.key_for_index([:name]), :ids => Set[@user.id]}
  end
  
  it 'saves multiple indexes with the same value as an array' do
    @user1 = User.create(:name => 'Josh')
    @user2 = User.create(:name => 'Josh')
    
    Dynamoid::Adapter.get_item("dynamoid_tests_index_user_names", @user1.key_for_index([:name])).should == {@user1.class.index_key_name([:name]).to_sym => @user1.key_for_index([:name]), :ids => Set[@user2.id, @user1.id]}
  end
    
end
