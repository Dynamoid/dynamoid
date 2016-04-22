require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::HasMany do
  let(:magazine) {Magazine.create}
  let(:user) {User.create}
  let(:camel_case) {CamelCase.create}

  it 'determines equality from its records' do
    subscription = magazine.subscriptions.create

    expect(magazine.subscriptions).to eq subscription
  end

  it 'determines target association correctly' do
    expect(magazine.subscriptions.send(:target_association)).to eq :magazine
    expect(user.books.send(:target_association)).to eq :owner
    expect(camel_case.users.send(:target_association)).to eq :camel_case
  end

  it 'determins target class correctly' do
    expect(magazine.subscriptions.send(:target_class)).to eq Subscription
    expect(user.books.send(:target_class)).to eq Magazine
  end

  it 'determines target attribute' do
    expect(magazine.subscriptions.send(:target_attribute)).to eq :magazine_ids
    expect(user.books.send(:target_attribute)).to eq :owner_ids
  end

  it 'associates belongs_to automatically' do
    subscription = magazine.subscriptions.create

    expect(subscription.magazine).to eq magazine

    magazine = user.books.create
    expect(magazine.owner).to eq user
  end

  it 'has a where method to filter associates' do
    red = magazine.camel_cases.create
    red.color = 'red'
    red.save

    blue = magazine.camel_cases.create
    blue.color = 'blue'
    blue.save

    expect(magazine.camel_cases.count).to eq 2
    expect(magazine.camel_cases.where(color: 'red').count).to eq 1
  end

  it 'is not modified by the where method' do
    red = magazine.camel_cases.create
    red.color = 'red'
    red.save

    blue = magazine.camel_cases.create
    blue.color = 'blue'
    blue.save

    expect(magazine.camel_cases.where(color: 'red').count).to eq 1
    expect(magazine.camel_cases.where(color: 'yellow').count).to eq 0
    expect(magazine.camel_cases.count).to eq 2
  end

end
