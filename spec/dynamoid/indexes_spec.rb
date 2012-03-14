require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Indexes" do
  
  before(:all) do
    User.create_indexes
  end

  it 'raises an error if a field does not exist' do
    lambda {User.send(:index, :test)}.should raise_error(Dynamoid::Errors::InvalidField)
  end
  
  it 'adds indexes to the index array' do
    User.indexes.should == {[:name]=>{:range_key=>nil, :hash_key=>[:name]}, [:email]=>{:range_key=>nil, :hash_key=>[:email]}, [:email, :name]=>{:range_key=>nil, :hash_key=>[:email, :name]}}
  end
  
  it 'reorders index names alphabetically' do
    User.indexes[[:email, :name]][:hash_key].should == [:email, :name]
  end
  
  it 'creates a name for a table index' do
    User.index_table_name([:email, :name]).should == 'dynamoid_tests_index_user_emails_and_names'
  end
  
  it 'assembles a hashed value for the key of an index' do
    @user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
    
    @user.key_for_index([:email, :name]).should == "Josh.josh@joshsymonds.com"
  end
  
  it 'saves indexes to their tables' do
    @user = User.create(:name => 'Josh')
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", @user.key_for_index([:name]))[:id].should == @user.key_for_index([:name])
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", @user.key_for_index([:name]))[:ids].should == Set[@user.id]
  end
  
  it 'saves multiple indexes with the same value as an array' do
    @user1 = User.create(:name => 'Josh')
    @user2 = User.create(:name => 'Josh')
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", @user1.key_for_index([:name]))[:id].should == @user1.key_for_index([:name])
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", @user1.key_for_index([:name]))[:ids].should == Set[@user2.id, @user1.id]
  end
  
  it 'deletes indexes when the object is destroyed' do
    @user = User.create(:name => 'Josh')
    @user.destroy
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", @user.key_for_index([:name]))[:id].should == @user.key_for_index([:name])
  end

  it 'handles empty indexes' do
    @user = User.create(:name => 'Josh')
    @user.destroy
    @user = User.create(:name => 'Josh')
  end
end
