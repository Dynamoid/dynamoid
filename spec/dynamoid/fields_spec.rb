require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Fields" do

  before do
    @address = Address.new
  end

  it 'declares read attributes' do
    @address.city.should be_nil
  end
  
  it 'declares write attributes' do
    @address.city = 'Chicago' 
    @address.city.should == 'Chicago'
  end
  
  it 'declares a query attribute' do
    @address.city?.should be_false
    
    @address.city = 'Chicago'
    
    @address.city?.should be_true
  end
  
end
