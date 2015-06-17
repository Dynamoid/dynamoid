require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::HasMany" do

  before do
    @magazine = Magazine.create
    @user = User.create
    @camel_case = CamelCase.create
  end
  
  it 'determines equality from its records' do
    @subscription = @magazine.subscriptions.create
    
    expect(@magazine.subscriptions).to eq @subscription
  end

  it 'determines target association correctly' do
    expect(@magazine.subscriptions.send(:target_association)).to eq :magazine
    expect(@user.books.send(:target_association)).to eq :owner
    expect(@camel_case.users.send(:target_association)).to eq :camel_case
  end

  it 'determins target class correctly' do
    expect(@magazine.subscriptions.send(:target_class)).to eq Subscription
    expect(@user.books.send(:target_class)).to eq Magazine
  end
  
  it 'determines target attribute' do
    expect(@magazine.subscriptions.send(:target_attribute)).to eq :magazine_ids
    expect(@user.books.send(:target_attribute)).to eq :owner_ids
  end
  
  it 'associates belongs_to automatically' do
    @subscription = @magazine.subscriptions.create
    
    expect(@subscription.magazine).to eq @magazine

    @magazine = @user.books.create
    expect(@magazine.owner).to eq @user
  end

end
