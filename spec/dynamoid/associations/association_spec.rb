require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::Association" do

  before do
    @magazine = Magazine.create
  end
  
  it 'returns an empty array if there are no associations' do
    @magazine.subscriptions.should be_empty
  end
  
  it 'adds an item to an association' do
    @subscription = Subscription.create
    
    @magazine.subscriptions << @subscription
    @magazine.subscriptions.size.should == 1
    @magazine.subscriptions.should include @subscription
  end
  
  it 'deletes an item from an association' do
    @subscription = Subscription.create
    @magazine.subscriptions << @subscription
    
    @magazine.subscriptions.delete(@subscription)
    @magazine.subscriptions.size.should == 0
  end
  
  it 'creates an item from an association' do
    @subscription = @magazine.subscriptions.create
    
    @subscription.class.should == Subscription
    @magazine.subscriptions.size.should == 1
    @magazine.subscriptions.should include @subscription
  end

end
