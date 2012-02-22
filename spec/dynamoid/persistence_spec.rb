require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Persistence" do
  
  before do
    Dynamoid.config {|config| config.adapter = 'local'}
    @address = Address.new
  end
  
  it 'creates a table when it saves to the datastore' do
    @address.save
    
    Dynamoid::Adapter.data.keys.should == ["dynamoid_addresses"]
  end
  
  it 'assigns itself an id on save' do
    @address.save
    
    Dynamoid::Adapter.data["dynamoid_addresses"][:data].should_not be_empty
  end
  
  it 'assigns itself an id on save only if it does not have one' do
    @address.id = 'test123'
    @address.save
    
    Dynamoid::Adapter.data.should == {"dynamoid_addresses" => { :id => :id, :data => {"test123"=>{:id=>"test123", :city=>nil}}}}
  end
  
  it 'has a table name' do
    Address.table_name.should == 'dynamoid_addresses'
  end
  
  it 'creates a table' do
    Address.create_table(Address.table_name)
    
    Dynamoid::Adapter.data.should == {"dynamoid_addresses" => { :id => :id, :data => {} }}
  end
  
  it 'checks if a table already exists' do
    Address.create_table(Address.table_name)
    
    Address.table_exists?(Address.table_name).should be_true
    Address.table_exists?('crazytable').should be_false
  end
  
  it 'saves indexes along with itself' do
    @user = User.new(:name => 'Josh')
    
    @user.expects(:save_indexes).once.returns(true)
    @user.save
  end

end
