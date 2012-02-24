require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Persistence" do
  
  before do
    @address = Address.new
  end
  
  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid::Adapter.delete_table(Address.table_name) if Dynamoid::Adapter.list_tables.include?(Address.table_name)
      end
    
      it 'creates a table' do
        Address.create_table(Address.table_name)

        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(Address.table_name)

        Address.table_exists?(Address.table_name).should be_true
        Address.table_exists?('crazytable').should be_false
      end
    end
  end
  
  
  it 'assigns itself an id on save' do
    @address.save
    
    Dynamoid::Adapter.get_item("dynamoid_tests_addresses", @address.id)[:id].should == @address.id
  end
  
  it 'assigns itself an id on save only if it does not have one' do
    @address.id = 'test123'
    @address.save
    
    Dynamoid::Adapter.get_item("dynamoid_tests_addresses", 'test123').should_not be_empty
  end
  
  it 'has a table name' do
    Address.table_name.should == 'dynamoid_tests_addresses'
  end
    
  it 'saves indexes along with itself' do
    @user = User.new(:name => 'Josh')
    
    @user.expects(:save_indexes).once.returns(true)
    @user.save
  end

end
