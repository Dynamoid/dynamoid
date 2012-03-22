require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::HasMany" do

  before do
    @magazine = Magazine.create
  end
  
  it 'determines equality from its records' do
    @subscription = @magazine.subscriptions.create
    
    @magazine.subscriptions.should == @subscription
  end

  it 'determines target association correctly' do
    @magazine.subscriptions.send(:target_association).should == :magazine
  end
  
  it 'determines target attribute' do
    @magazine.subscriptions.send(:target_attribute).should == :magazine_ids
  end
  
  it 'associates belongs_to automatically' do
    @subscription = @magazine.subscriptions.create
    
    @subscription.magazine.should == @magazine
  end

end
