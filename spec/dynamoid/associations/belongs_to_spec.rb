require 'active_support'
require 'active_support/core_ext/object'

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::BelongsTo do
  let(:subscription) {Subscription.create}

  context 'has many' do
    let(:camel_case) {CamelCase.create}
    let(:magazine) {subscription.magazine.create}
    let(:user) {magazine.owner.create}

    it 'determines nil if it has no associated record' do
      expect(subscription.magazine).to be_nil
    end

    it 'determines target association correctly' do
      expect(camel_case.magazine.send(:target_association)).to eq :camel_cases
    end

    it 'delegates equality to its source record' do
      expect(subscription.magazine).to eq magazine
      expect(magazine.subscriptions).to include subscription
    end

    it 'associates has_many automatically' do
      expect(user.books.size).to eq 1
      expect(user.books).to include magazine
    end

    it 'behaves like the object it is trying to be' do
      expect(magazine.subscriptions).to include subscription
      subscription.magazine.update_attribute(:title, 'Test Title')

      expect(Magazine.first.title).to eq 'Test Title'
    end
  end

  context 'has one' do
    let(:sponsor) {Sponsor.create}
    let(:magazine) {sponsor.magazine.create}
    let(:user) {subscription.customer.create}

    it 'considers an association nil/blank if it has no associated record' do
      expect(sponsor.magazine).to be_nil
      expect(sponsor.magazine).to be_blank
    end

    it 'considers an association present if it has an associated record' do
      sponsor.magazine.create

      expect(magazine.sponsor).to be_present
    end

    it 'delegates equality to its source record' do
      expect(sponsor.magazine).to eq magazine
    end

    it 'associates has_one automatically' do
      expect(magazine.sponsor).to eq sponsor
      expect(user.monthly).to eq subscription
    end
  end
end
