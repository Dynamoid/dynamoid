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
  
  it 'returns the number of items in the association' do
    @magazine.subscriptions.create
    
    @magazine.subscriptions.size.should == 1
    
    @magazine.subscriptions.create
    
    @magazine.subscriptions.size.should == 2
  end
  
  it 'assigns directly via the equals operator' do
    @subscription = Subscription.create
    @magazine.subscriptions = [@subscription]
    
    @magazine.subscriptions.should == [@subscription]
  end
  
  it 'assigns directly via the equals operator and reflects to the target association' do
    @subscription = Subscription.create
    @magazine.subscriptions = [@subscription]
    
    @subscription.magazine.should == @magazine
  end
  
  it 'does not assign reflection association if the reflection association does not exist' do
    @sponsor = Sponsor.create
    
    @subscription = @sponsor.subscriptions.create
    @subscription.should_not respond_to :sponsor
    @subscription.should_not respond_to :sponsors
    @subscription.should_not respond_to :sponsors_ids
    @subscription.should_not respond_to :sponsor_ids
  end

end
