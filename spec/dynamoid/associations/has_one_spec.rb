require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::HasOne" do

  before do
    @magazine = Magazine.create
    @user = User.create
    @camel_case = CamelCase.create
  end
  
  it 'determines nil if it has no associated record' do
    @magazine.sponsor.should be_nil
  end

  it 'determines target association correctly' do
    @camel_case.sponsor.send(:target_association).should == :camel_case
  end
  
  it 'returns only one object when associated' do
    @magazine.sponsor.create
    
    @magazine.sponsor.should_not be_a_kind_of Array
  end
  
  it 'delegates equality to its source record' do
    @sponsor = @magazine.sponsor.create
    
    @magazine.sponsor.should == @sponsor
  end
  
  it 'is equal from its target record' do
    @sponsor = @magazine.sponsor.create
    
    @magazine.sponsor.should == @sponsor
  end
  
  it 'associates belongs_to automatically' do
    @sponsor = @magazine.sponsor.create
    @sponsor.magazine.should == @magazine
    @magazine.sponsor.should == @sponsor

    @subscription = @user.monthly.create
    @subscription.customer.should == @user
  end
end
