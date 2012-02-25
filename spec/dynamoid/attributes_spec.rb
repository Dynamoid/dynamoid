require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Attributes" do

  before do
    @address = Address.new
  end

  it 'should write an attribute correctly' do
    @address.write_attribute(:city, 'Chicago')
  end
  
  it 'should write an attribute with the alias' do
    @address[:city] = 'Chicago'
  end
  
  it 'should read a written attribute' do
    @address.write_attribute(:city, 'Chicago')
    @address.read_attribute(:city).should == 'Chicago'
  end
  
  it 'should read a written attribute with the alias' do
    @address.write_attribute(:city, 'Chicago')
    @address[:city].should == 'Chicago'
  end
  
  it 'should update all attributes' do
    @address.expects(:save).once.returns(true)
    @address.update_attributes(:city => 'Chicago')
    @address[:city].should == 'Chicago'
  end
  
  it 'should update one attribute' do
    @address.expects(:save).once.returns(true)
    @address.update_attribute(:city, 'Chicago')
    @address[:city].should == 'Chicago'
  end
  
  it 'returns all attributes' do
    Address.attributes.should == [:id, :city]
  end

end
