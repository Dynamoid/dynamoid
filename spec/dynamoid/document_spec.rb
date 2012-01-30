require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Document" do

  it 'creates a new document' do
    @address = Address.new
    
    @address.new_record.should be_true
    @address.attributes.should == {:id => nil, :city => nil}
  end
  
  it 'creates a new document with attributes' do
    @address = Address.new(:city => 'Chicago')
    
    @address.new_record.should be_true
    
    @address.attributes.should == {:id => nil, :city => 'Chicago'}
  end
end
