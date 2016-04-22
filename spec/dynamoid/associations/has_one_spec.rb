require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::HasOne do
  let(:magazine) {Magazine.create}
  let(:user) {User.create}
  let(:camel_case) {CamelCase.create}

  it 'determines nil if it has no associated record' do
    expect(magazine.sponsor).to be_nil
  end

  it 'determines target association correctly' do
    expect(camel_case.sponsor.send(:target_association)).to eq :camel_case
  end

  it 'returns only one object when associated' do
    magazine.sponsor.create

    expect(magazine.sponsor).to_not be_a_kind_of Array
  end

  it 'delegates equality to its source record' do
    sponsor = magazine.sponsor.create

    expect(magazine.sponsor).to eq sponsor
  end

  it 'is equal from its target record' do
    sponsor = magazine.sponsor.create

    expect(magazine.sponsor).to eq sponsor
  end

  it 'associates belongs_to automatically' do
    sponsor = magazine.sponsor.create
    expect(sponsor.magazine).to eq magazine
    expect(magazine.sponsor).to eq sponsor

    subscription = user.monthly.create
    expect(subscription.customer).to eq user
  end
end
