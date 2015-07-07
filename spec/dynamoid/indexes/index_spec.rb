require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Indexes::Index" do
  
  before do
    @time = DateTime.now
    @index = Dynamoid::Indexes::Index.new(User, [:password, :name], :range_key => :created_at)
  end

  it 'reorders keys alphabetically' do
    expect(@index.sort([:password, :name, :created_at])).to eq [:created_at, :name, :password]
  end
  
  it 'assigns itself hash keys' do
    expect(@index.hash_keys).to eq [:name, :password]
  end
  
  it 'assigns itself range keys' do
    expect(@index.range_keys).to eq [:created_at]
  end
  
  it 'reorders its name automatically' do
    expect(@index.name).to eq [:created_at, :name, :password]
  end
  
  it 'determines its own table name' do
    expect(@index.table_name).to eq 'dynamoid_tests_index_user_created_ats_and_names_and_passwords'
  end
  
  it 'raises an error if a field does not exist' do
    expect{@index = Dynamoid::Indexes::Index.new(User, [:password, :text])}.to raise_error(Dynamoid::Errors::InvalidField)
  end
  
  it 'returns values for indexes' do
    expect(@index.values(:name => 'Josh', :password => 'test123', :created_at => @time)).to eq({:hash_value => 'Josh.test123', :range_value => @time.to_f})
  end
  
  it 'ignores values for fields that do not exist' do
    expect(@index.values(:name => 'Josh', :password => 'test123', :created_at => @time, :email => 'josh@joshsymonds.com')).to eq ({:hash_value => 'Josh.test123', :range_value => @time.to_f})
  end
  
  it 'substitutes a blank string for a hash value that does not exist' do
    expect(@index.values(:name => 'Josh', :created_at => @time)).to eq ({:hash_value => 'Josh.', :range_value => @time.to_f})
  end
  
  it 'substitutes a blank string if both hash values do not exist' do
    expect(@index.values(:created_at => @time)).to eq({:hash_value => '.', :range_value => @time.to_f})
  end
  
  it 'accepts values from an object instead of a hash' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)
    
    expect(@index.values(@user)).to eq({:hash_value => 'Josh.test123', :range_value => @time.to_f})
  end
  
  it 'accepts values from an object and returns changed values' do
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time)
    @user.name = 'Justin'
    
    expect(@index.values(@user)).to eq({:hash_value => 'Justin.test123', :range_value => @time.to_f})
  end
  
  it 'saves an object to the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.new(:name => 'Josh', :password => 'test123', :created_at => @time, :id => 'test123')
    
    @index.save(@user)
    
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids]).to eq Set['test123']
  end
  
  it 'saves an object to the index it is associated with with a range' do
    @index = Dynamoid::Indexes::Index.new(User, :name, :range_key => :last_logged_in_at)
    @user = User.create(:name => 'Josh', :last_logged_in_at => @time)
    
    @index.save(@user)
    
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_last_logged_in_ats_and_names", 'Josh', :range_key => @time.to_f)[:ids]).to eq Set[@user.id]
  end
  
  it 'deletes an object from the index it is associated with' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')
    
    @index.save(@user)
    @index.delete(@user)
    
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids]).to be_nil
  end
  
  it 'updates an object by removing it from its previous index and adding it to its new one' do
    @index = Dynamoid::Indexes::Index.new(User, :name)
    @user = User.create(:name => 'Josh', :password => 'test123', :last_logged_in_at => @time, :id => 'test123')

    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids]).to eq Set['test123']
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin')).to be_nil

    @user.update_attributes(:name => 'Justin')
    
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Josh')[:ids]).to be_nil
    expect(Dynamoid::Adapter.read("dynamoid_tests_index_user_names", 'Justin')[:ids]).to eq Set['test123']
  end
  
end
