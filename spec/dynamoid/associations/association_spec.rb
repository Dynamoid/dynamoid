require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::Association" do

  before do
    Subscription.create_table_if_neccessary
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
    
    @second = @magazine.subscriptions.create
    @magazine.subscriptions.size.should == 2

    @magazine.subscriptions.delete(@second)
    @magazine.subscriptions.size.should == 1

    @magazine.subscriptions = []
    @magazine.subscriptions.size.should == 0
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
  
  it 'deletes all items from the association' do
    @magazine.subscriptions << Subscription.create
    @magazine.subscriptions << Subscription.create
    @magazine.subscriptions << Subscription.create
    
    @magazine.subscriptions.size.should == 3
    
    @magazine.subscriptions = nil
    @magazine.subscriptions.size.should == 0
  end
  
  it 'uses where inside an association and returns a result' do
    @included_subscription = @magazine.subscriptions.create(:length => 10)
    @unincldued_subscription = @magazine.subscriptions.create(:length => 8)
    
    @magazine.subscriptions.where(:length => 10).all.should == [@included_subscription]
  end
  
  it 'uses where inside an association and returns an empty set' do
    @included_subscription = @magazine.subscriptions.create(:length => 10)
    @unincldued_subscription = @magazine.subscriptions.create(:length => 8)
    
    @magazine.subscriptions.where(:length => 6).all.should be_empty
  end
  
  it 'includes enumerable' do
    @subscription1 = @magazine.subscriptions.create
    @subscription2 = @magazine.subscriptions.create
    @subscription3 = @magazine.subscriptions.create
    
    @magazine.subscriptions.collect(&:id).should =~ [@subscription1.id, @subscription2.id, @subscription3.id]
  end

  it 'works for camel-cased associations' do
    @magazine.camel_cases.create.class.should == CamelCase
  end

  it 'destroys associations' do
    @subscription = Subscription.new
    @magazine.subscriptions.expects(:target).returns([@subscription])
    @subscription.expects(:destroy)

    @magazine.subscriptions.destroy_all
  end

  it 'deletes associations' do
    @subscription = Subscription.new
    @magazine.subscriptions.expects(:target).returns([@subscription])
    @subscription.expects(:delete)

    @magazine.subscriptions.delete_all
  end

  it 'returns the first and last record when they exist' do
    @subscription1 = @magazine.subscriptions.create
    @subscription2 = @magazine.subscriptions.create
    @subscription3 = @magazine.subscriptions.create

    @magazine.subscriptions.instance_eval { [first, last] }.should == [@subscription1, @subscription3]
  end
  
  it 'replaces existing associations when using the setter' do
    @subscription1 = @magazine.subscriptions.create
    @subscription2 = @magazine.subscriptions.create
    @subscription3 = Subscription.create
    
    @subscription1.reload.magazine_ids.should_not be_nil
    @subscription2.reload.magazine_ids.should_not be_nil

    @magazine.subscriptions = @subscription3
    @magazine.subscriptions_ids.should == Set[@subscription3.id]
    
    @subscription1.reload.magazine_ids.should be_nil
    @subscription2.reload.magazine_ids.should be_nil
    @subscription3.reload.magazine_ids.should == Set[@magazine.id]
  end
  
  it 'destroys all objects and removes them from the association' do
    @subscription1 = @magazine.subscriptions.create
    @subscription2 = @magazine.subscriptions.create
    @subscription3 = @magazine.subscriptions.create

    @magazine.subscriptions.destroy_all
    
    @magazine.subscriptions.should be_empty
    Subscription.all.should be_empty
  end
  
  it 'deletes all objects and removes them from the association' do
    @subscription1 = @magazine.subscriptions.create
    @subscription2 = @magazine.subscriptions.create
    @subscription3 = @magazine.subscriptions.create

    @magazine.subscriptions.delete_all
    
    @magazine.subscriptions.should be_empty
    Subscription.all.should be_empty
  end

  it 'delegates class to the association object' do
    @magazine.sponsor.class.should == nil.class
    @magazine.sponsor.create
    @magazine.sponsor.class.should == Sponsor

    @magazine.subscriptions.class.should == Array
    @magazine.subscriptions.create
    @magazine.subscriptions.class.should == Array
  end

  it 'loads association one time only' do
    @sponsor = @magazine.sponsor.create
    @magazine.sponsor.expects(:find_target).once.returns(@sponsor)

    @magazine.sponsor.id
    @magazine.sponsor.id
  end

end
