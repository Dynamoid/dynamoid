require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::Chain" do

  before(:each) do
    @user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com', :password => 'Test123')
    @chain = Dynamoid::Criteria::Chain.new(User)
  end
  
  it 'finds matching index for a query' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:index).should == [:name]
    
    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:index).should == [:email]
    
    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:index).should == [:email, :name]
  end
  
  it 'does not find an index if there is not an appropriate one' do
    @chain.query = {:password => 'Test123'}
    @chain.send(:index).should == []
  end
  
  it 'returns values for index for a query' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:values_for_index).should == ['Josh']
    
    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:values_for_index).should == ['josh@joshsymonds.com']
    
    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:values_for_index).should == ['josh@joshsymonds.com', 'Josh']
  end
  
  it 'finds records with an index' do
    @chain.query = {:name => 'Josh'}
    @chain.send(:records_with_index).should == [@user]
    
    @chain.query = {:email => 'josh@joshsymonds.com'}
    @chain.send(:records_with_index).should == [@user]
    
    @chain.query = {:name => 'Josh', :email => 'josh@joshsymonds.com'}
    @chain.send(:records_with_index).should == [@user]
  end
  
  it 'finds records without an index' do
    @chain.query = {:password => 'Test123'}
    @chain.send(:records_without_index).should == [@user]
  end
  
  it 'defines each' do
    @chain.query = {:name => 'Josh'}
    @chain.each {|u| u.update_attribute(:name, 'Justin')}
    
    User.find(@user.id).name.should == 'Justin'
  end
  
  it 'includes Enumerable' do
    @chain.query = {:name => 'Josh'}
    
    @chain.collect {|u| u.name}.should == ['Josh']
  end
  
end
