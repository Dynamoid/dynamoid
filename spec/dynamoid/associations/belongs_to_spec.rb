require 'active_support'
require 'active_support/core_ext/object'

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::BelongsTo do
  context 'has many' do
    let(:subscription) {Subscription.create}
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
    let(:subscription) {Subscription.create}
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

  describe "{association}=" do
    context "has many" do
      it "stores the same object on this side" do
        subscription = Subscription.create
        magazine = Magazine.create

        subscription.magazine = magazine
        expect(subscription.magazine.target.object_id).to eq(magazine.object_id)
      end

      it "does not store the same object on that side" do
        subscription = Subscription.create
        magazine = Magazine.create

        subscription.magazine = magazine
        expect(magazine.subscriptions.target[0].object_id).to_not eq(subscription.object_id)
      end
    end

    context "has one" do
      it "stores the same object on this side" do
        sponsor = Sponsor.create
        magazine = Magazine.create

        sponsor.magazine = magazine
        expect(sponsor.magazine.target.object_id).to eq(magazine.object_id)
      end

      it "does not store the same object on that side" do
        sponsor = Sponsor.create
        magazine = Magazine.create

        sponsor.magazine = magazine
        expect(magazine.sponsor.target.object_id).to_not eq(sponsor.object_id)
      end
    end
  end

  context "set to nil" do
    it 'can be set to nil' do
      subscription = Subscription.new

      expect { subscription.magazine = nil }.not_to raise_error
      expect(subscription.magazine).to eq nil

      subscription.save!
      expect(Subscription.find(subscription.id).magazine).to eq nil
    end

    it "overrides previous saved value" do
      magazine = Magazine.create!
      subscription = Subscription.create!(magazine: magazine)

      expect {
        subscription.magazine = nil
        subscription.save!
      }.to change {
        Subscription.find(subscription.id).magazine.target
      }.from(magazine).to(nil)
    end

    it "updates association on the other side" do
      magazine = Magazine.create!
      subscription = Subscription.create!(magazine: magazine)

      expect {
        subscription.magazine = nil
        subscription.save!
      }.to change {
        Magazine.find(magazine.title).subscriptions.to_a
      }.from([subscription]).to([])
    end
  end

  describe "#delete" do
    it "clears association on this side" do
      subscription = Subscription.create
      magazine = subscription.magazine.create

      expect {
        subscription.magazine.delete
      }.to change { subscription.magazine.target }.from(magazine).to(nil)
    end

    it "persists changes on this side" do
      subscription = Subscription.create
      magazine = subscription.magazine.create

      expect {
        subscription.magazine.delete
      }.to change { Subscription.find(subscription.id).magazine.target }.from(magazine).to(nil)
    end

    context "has many" do
      let(:subscription) { Subscription.create }
      let!(:magazine) { subscription.magazine.create }

      it "clears association on that side" do
        expect {
          subscription.magazine.delete
        }.to change { magazine.subscriptions.target }.from([subscription]).to([])
      end

      it "persists changes on that side" do
        expect {
          subscription.magazine.delete
        }.to change { Magazine.find(magazine.title).subscriptions.target }.from([subscription]).to([])
      end
    end

    context "has one" do
      let(:sponsor) { Sponsor.create }
      let!(:magazine) { sponsor.magazine.create }

      it "clears association on that side" do
        expect {
          sponsor.magazine.delete
        }.to change { magazine.sponsor.target }.from(sponsor).to(nil)
      end

      it "persists changes on that side" do
        expect {
          sponsor.magazine.delete
        }.to change { Magazine.find(magazine.title).sponsor.target }.from(sponsor).to(nil)
      end
    end
  end
end
