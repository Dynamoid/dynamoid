require 'active_support'
require 'active_support/core_ext/object'

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::HasOne do
  let(:magazine) {Magazine.create}
  let(:user) {User.create}
  let(:camel_case) {CamelCase.create}

  it 'considers an association nil/blank if it has no associated record' do
    expect(magazine.sponsor).to be_nil
    expect(magazine.sponsor).to be_blank
  end

  it 'considers an association present if it has an associated record' do
    magazine.sponsor.create

    expect(magazine.sponsor).to be_present
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

  describe "{association}=" do
    context "belongs to" do
      it "stores the same object on this side" do
        magazine = Magazine.create!
        sponsor = Sponsor.create!

        magazine.sponsor = sponsor
        expect(magazine.sponsor.target.object_id).to eq(sponsor.object_id)
      end

      it "does not store the same object on that side" do
        magazine = Magazine.create!
        sponsor = Sponsor.create!

        magazine.sponsor = sponsor
        expect(sponsor.magazine.target.object_id).not_to eq(magazine.object_id)
      end
    end
  end
end
