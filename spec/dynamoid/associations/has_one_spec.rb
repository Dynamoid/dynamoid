# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/object'

require 'spec_helper'

describe Dynamoid::Associations::HasOne do
  let(:magazine) { Magazine.create }
  let(:user) { User.create }
  let(:camel_case) { CamelCase.create }

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

  describe 'assigning' do
    context 'belongs to' do
      let(:magazine) { Magazine.create }

      it 'associates model on this side' do
        sponsor = Sponsor.create
        magazine.sponsor = sponsor

        expect(magazine.sponsor).to eq(sponsor)
      end

      it 'associates model on that side' do
        sponsor = Sponsor.create
        magazine.sponsor = sponsor

        expect(sponsor.magazine).to eq(magazine)
      end

      it 're-associates model on this side' do
        sponsor_old = Sponsor.create
        sponsor_new = Sponsor.create
        magazine.sponsor = sponsor_old

        expect do
          magazine.sponsor = sponsor_new
        end.to change { magazine.sponsor.target }.from(sponsor_old).to(sponsor_new)
      end

      it 're-associates model on that side' do
        sponsor_old = Sponsor.create
        sponsor_new = Sponsor.create

        magazine.sponsor = sponsor_old
        expect do
          magazine.sponsor = sponsor_new
        end.to change { sponsor_new.magazine.target }.from(nil).to(magazine)
      end

      it 'deletes previous model from association' do
        sponsor_old = Sponsor.create
        sponsor_new = Sponsor.create

        magazine.sponsor = sponsor_old
        expect do
          magazine.sponsor = sponsor_new
        end.to change { sponsor_old.magazine.target }.from(magazine).to(nil)
      end

      it 'stores the same object on this side' do
        sponsor = Sponsor.create
        magazine.sponsor = sponsor

        expect(magazine.sponsor.target.object_id).to eq(sponsor.object_id)
      end

      it 'does not store the same object on that side' do
        sponsor = Sponsor.create!
        magazine.sponsor = sponsor

        expect(sponsor.magazine.target.object_id).not_to eq(magazine.object_id)
      end
    end
  end

  context 'set to nil' do
    it 'can be set to nil' do
      magazine = Magazine.create!

      expect { magazine.sponsor = nil }.not_to raise_error
      expect(magazine.sponsor).to eq nil

      magazine.save!
      expect(Magazine.find(magazine.title).sponsor).to eq nil
    end

    it 'overrides previous saved value' do
      sponsor = Sponsor.create!
      magazine = Magazine.create!(sponsor: sponsor)

      expect do
        magazine.sponsor = nil
        magazine.save!
      end.to change {
        Magazine.find(magazine.title).sponsor.target
      }.from(sponsor).to(nil)
    end

    it 'updates association on the other side' do
      sponsor = Sponsor.create!
      magazine = Magazine.create!(sponsor: sponsor)

      expect do
        magazine.sponsor = nil
        magazine.save!
      end.to change {
        Sponsor.find(sponsor.id).magazine.target
      }.from(magazine).to(nil)
    end
  end

  describe '#delete' do
    it 'clears association on this side' do
      magazine = Magazine.create
      sponsor = magazine.sponsor.create

      expect do
        magazine.sponsor.delete
      end.to change { magazine.sponsor.target }.from(sponsor).to(nil)
    end

    it 'persists changes on this side' do
      magazine = Magazine.create
      sponsor = magazine.sponsor.create

      expect do
        magazine.sponsor.delete
      end.to change { Magazine.find(magazine.title).sponsor.target }.from(sponsor).to(nil)
    end

    context 'belongs to' do
      let(:magazine) { Magazine.create }
      let!(:sponsor) { magazine.sponsor.create }

      it 'clears association on that side' do
        expect do
          magazine.sponsor.delete
        end.to change { sponsor.magazine.target }.from(magazine).to(nil)
      end

      it 'persists changes on that side' do
        expect do
          magazine.sponsor.delete
        end.to change { Sponsor.find(sponsor.id).magazine.target }.from(magazine).to(nil)
      end
    end
  end
end
