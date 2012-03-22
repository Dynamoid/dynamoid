require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::HasMany" do

  before do
    @magazine = Magazine.create
    @user = User.create
  end
  
  it 'determines equality from its records' do
    @subscription = @magazine.subscriptions.create
    
    @magazine.subscriptions.should == @subscription
  end

  it 'determines target association correctly' do
    @magazine.subscriptions.send(:target_association).should == :magazine
    @user.books.send(:target_association).should == :owner
  end

  it 'determins target class correctly' do
    @magazine.subscriptions.send(:target_class).should == Subscription
    @user.books.send(:target_class).should == Magazine
  end
  
  it 'determines target attribute' do
    @magazine.subscriptions.send(:target_attribute).should == :magazine_ids
    @user.books.send(:target_attribute).should == :owner_ids
  end
  
  it 'associates belongs_to automatically' do
    @subscription = @magazine.subscriptions.create
    
    @subscription.magazine.should == @magazine

    @magazine = @user.books.create
    @magazine.owner.should == @user
  end

end
