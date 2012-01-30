require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Persistence" do
  
  before do
    Dynamoid.config {|config| config.adapter = 'local'}
    @address = Address.new
  end
  
  after do
    Dynamoid::Adapter.reset_data
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
    Address.create_table
    
    Dynamoid::Adapter.data.should == {"dynamoid_addresses" => { :id => :id, :data => {} }}
  end

end
