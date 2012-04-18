require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Indexes::Index" do
  
  before do
    @time = DateTime.now
    @index = Dynamoid::Indexes::Index.new(User, [:password, :name], :range_key => :created_at)
  end

  it 'reorders keys alphabetically' do
    @index.sort([:password, :name, :created_at]).should == [:created_at, :name, :password]
  end
  
  it 'assigns itself hash keys' do
    @index.hash_keys.should == [:name, :password]
  end
  
  it 'assigns itself range keys' do
    @index.range_keys.should == [:created_at]
  end
  
  it 'reorders its name automatically' do
    @index.name.should == [:created_at, :name, :password]
  end
  
  it 'determines its own table name' do
    @index.table_name.should == 'dynamoid_tests_index_user_created_ats_and_names_and_passwords'
  end
  
  it 'raises an error if a field does not exist' do
    lambda {@index = Dynamoid::Indexes::Index.new(User, [:password, :text])}.should raise_error(Dynamoid::Errors::InvalidField)
  end
  
  it 'returns values for indexes' do
    @index.values(:name => 'Josh', :password => 'test123', :created_at => @time).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end
  
  it 'ignores values for fields that do not exist' do
    @index.values(:name => 'Josh', :password => 'test123', :created_at => @time, :email => 'josh@joshsymonds.com').should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end
  
  it 'substitutes a blank string for a hash value that does not exist' do
    @index.values(:name => 'Josh', :created_at => @time).should == {:hash_value => 'Josh.', :range_value => @time.to_f}
  end
  
  it 'substitutes a blank string if both hash values do not exist' do
    @index.values(:created_at => @time).should == {:hash_value => '.', :range_value => @time.to_f}
  end
  
  it 'accepts values from an object instead of a hash' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)
    
    @index.values(@user).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
  end
  
  it 'accepts values from an object and returns changed values' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)
    @user.name = 'Justin'
    
    @index.values(@user, true).should == {:hash_value => 'Josh.test123', :range_value => @time.to_f}
    
    @index.values(@user).should == {:hash_value => 'Justin.test123', :range_value => @time.to_f}
  end
  
  it 'saves an object to the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time, :id => 'test123')
    
    @index.save(@user)
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should == Set['test123']
  end
  
  it 'saves an object to the index it is associated with with a range' do
    @index = Dynamoid::Indexes::Index.new(User, :name, :range_key => :last_logged_in_at)
    @user = User.create(:name => 'Josh', :last_logged_in_at => @time)
    
    @index.save(@user)
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_last_logged_in_ats_and_names", 'Josh', :range_key => @time.to_f)[:ids].should == Set[@user.id]
  end
  
  it 'deletes an object from the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')
    
    @index.save(@user)
    @index.delete(@user)
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should be_nil
  end
  
  it 'updates an object by removing it from its previous index and adding it to its new one' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')

    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should == Set['test123']
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin').should be_nil

    @user.update_attributes(:name => 'Justin')
    
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids].should be_nil
    Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin')[:ids].should == Set['test123']
  end
  
end
