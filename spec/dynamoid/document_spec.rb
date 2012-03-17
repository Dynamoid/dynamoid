require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Document" do

  it 'initializes a new document' do
    @address = Address.new
    
    @address.new_record.should be_true
    @address.attributes.should == {:id=>nil, :created_at=>nil, :updated_at=>nil, :city=>nil, :options=>nil}
  end
  
  it 'initializes a new document with attributes' do
    @address = Address.new(:city => 'Chicago')
    
    @address.new_record.should be_true
    
    @address.attributes.should == {:id=>nil, :created_at=>nil, :updated_at=>nil, :city=>"Chicago", :options=>nil}
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

  it 'is not equivalent to another document' do
    @address.should_not == Address.create
  end
  
  it 'is not equivalent to another object' do
    @address = Address.create(:city => 'Chicago')
    @address.should_not == "test"
  end
  
  it "isn't equal to nil" do
    @address = Address.create(:city => 'Chicago')
    @address.should_not == nil
  end
  
  it 'gets errors courtesy of ActiveModel' do
    @address = Address.create(:city => 'Chicago')
    
    @address.errors.should be_empty
    @address.errors.full_messages.should be_empty
  end
  
  it 'reloads itself and sees persisted changes' do
    @address = Address.create
    
    Address.first.update_attributes(:city => 'Chicago')
    
    @address.city.should be_nil
    @address.reload.city.should == 'Chicago'
  end
end
