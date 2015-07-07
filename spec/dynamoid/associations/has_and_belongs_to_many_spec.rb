require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::HasAndBelongsToMany do
  let(:subscription) {Subscription.create}
  let(:camel_case) {CamelCase.create}

  it 'determines equality from its records' do
    user = subscription.users.create
    
    expect(subscription.users.size).to eq 1
    expect(subscription.users).to include user
  end

  it 'determines target association correctly' do
    expect(subscription.users.send(:target_association)).to eq :subscriptions
    expect(camel_case.subscriptions.send(:target_association)).to eq :camel_cases
  end
  
  it 'determines target attribute' do
    expect(subscription.users.send(:target_attribute)).to eq :subscriptions_ids
  end
  
  it 'associates has_and_belongs_to_many automatically' do
    user = subscription.users.create
    
    expect(user.subscriptions.size).to eq 1
    expect(user.subscriptions).to include subscription
    expect(subscription.users.size).to eq 1
    expect(subscription.users).to include user

    user = User.create
    follower = user.followers.create
    expect(follower.following).to include user
    expect(user.followers).to include follower
  end
  
  it 'disassociates has_and_belongs_to_many automatically' do
    user = subscription.users.create
    
    subscription.users.delete(user)
    expect(subscription.users.size).to eq 0
    expect(user.subscriptions.size).to eq 0
  end
end
