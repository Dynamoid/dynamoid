# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/object'

require 'spec_helper'

describe Dynamoid::Associations::BelongsTo do
  context 'has many' do
    let(:subscription) { Subscription.create }
    let(:camel_case) { CamelCase.create }
    let(:magazine) { subscription.magazine.create }
    let(:user) { magazine.owner.create }

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

    context 'proxied behavior' do
      let(:proxy) do
        expect(magazine.subscriptions).to include(subscription)
        subscription.magazine
      end

      it 'forwards dynamoid methods' do
        proxy.update_attribute(:size, 101)

        expect(Magazine.first.size).to eq 101
      end

      it 'forwards business-logic methods' do
        expect(proxy.respond_to?(:publish)).to eq true
        expect(proxy.publish(advertisements: 10)).to eq 10
        expect(proxy.publish(advertisements: 10, free_issue: true) { |c| c *= 42 }).to eq 840
      end
    end
  end

  context 'has one' do
    let(:subscription) { Subscription.create }
    let(:sponsor) { Sponsor.create }
    let(:magazine) { sponsor.magazine.create }
    let(:user) { subscription.customer.create }

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

  describe 'assigning' do
    context 'has many' do
      let(:subscription) { Subscription.create }

      it 'associates model on this side' do
        magazine = Magazine.create
        subscription.magazine = magazine

        expect(subscription.magazine).to eq(magazine)
      end

      it 'associates model on that side' do
        magazine = Magazine.create
        subscription.magazine = magazine

        expect(magazine.subscriptions.to_a).to eq([subscription])
      end

      it 're-associates model on this side' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        subscription.magazine = magazine_old

        expect do
          subscription.magazine = magazine_new
        end.to change { subscription.magazine.target }.from(magazine_old).to(magazine_new)
      end

      it 're-associates model on that side' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        subscription.magazine = magazine_old

        expect do
          subscription.magazine = magazine_new
        end.to change { magazine_new.subscriptions.target }.from([]).to([subscription])
      end

      it 'deletes previous model from association' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        subscription.magazine = magazine_old

        expect do
          subscription.magazine = magazine_new
        end.to change { magazine_old.subscriptions.to_a }.from([subscription]).to([])
      end

      it 'stores the same object on this side' do
        magazine = Magazine.create
        subscription.magazine = magazine

        expect(subscription.magazine.target.object_id).to eq(magazine.object_id)
      end

      it 'does not store the same object on that side' do
        magazine = Magazine.create
        subscription.magazine = magazine

        expect(magazine.subscriptions.target[0].object_id).not_to eq(subscription.object_id)
      end
    end

    context 'has one' do
      let(:sponsor) { Sponsor.create }

      it 'associates model on this side' do
        magazine = Magazine.create
        sponsor.magazine = magazine

        expect(sponsor.magazine).to eq(magazine)
      end

      it 'associates model on that side' do
        magazine = Magazine.create
        sponsor.magazine = magazine

        expect(magazine.sponsor).to eq(sponsor)
      end

      it 're-associates model on this side' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        sponsor.magazine = magazine_old

        expect do
          sponsor.magazine = magazine_new
        end.to change { sponsor.magazine.target }.from(magazine_old).to(magazine_new)
      end

      it 're-associates model on this side' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        sponsor.magazine = magazine_old

        expect do
          sponsor.magazine = magazine_new
        end.to change { magazine_new.sponsor.target }.from(nil).to(sponsor)
      end

      it 'deletes previous model from association' do
        magazine_old = Magazine.create
        magazine_new = Magazine.create
        sponsor.magazine = magazine_old

        expect do
          sponsor.magazine = magazine_new
        end.to change { magazine_old.sponsor.target }.from(sponsor).to(nil)
      end

      it 'stores the same object on this side' do
        magazine = Magazine.create
        sponsor.magazine = magazine

        expect(sponsor.magazine.target.object_id).to eq(magazine.object_id)
      end

      it 'does not store the same object on that side' do
        magazine = Magazine.create

        sponsor.magazine = magazine
        expect(magazine.sponsor.target.object_id).not_to eq(sponsor.object_id)
      end
    end
  end

  context 'set to nil' do
    it 'can be set to nil' do
      subscription = Subscription.new

      expect { subscription.magazine = nil }.not_to raise_error
      expect(subscription.magazine).to eq nil

      subscription.save!
      expect(Subscription.find(subscription.id).magazine).to eq nil
    end

    it 'overrides previous saved value' do
      magazine = Magazine.create!
      subscription = Subscription.create!(magazine: magazine)

      expect do
        subscription.magazine = nil
        subscription.save!
      end.to change {
        Subscription.find(subscription.id).magazine.target
      }.from(magazine).to(nil)
    end

    it 'updates association on the other side' do
      magazine = Magazine.create!
      subscription = Subscription.create!(magazine: magazine)

      expect do
        subscription.magazine = nil
        subscription.save!
      end.to change {
        Magazine.find(magazine.title).subscriptions.to_a
      }.from([subscription]).to([])
    end
  end

  describe '#delete' do
    it 'clears association on this side' do
      subscription = Subscription.create
      magazine = subscription.magazine.create

      expect do
        subscription.magazine.delete
      end.to change { subscription.magazine.target }.from(magazine).to(nil)
    end

    it 'persists changes on this side' do
      subscription = Subscription.create
      magazine = subscription.magazine.create

      expect do
        subscription.magazine.delete
      end.to change { Subscription.find(subscription.id).magazine.target }.from(magazine).to(nil)
    end

    context 'has many' do
      let(:subscription) { Subscription.create }
      let!(:magazine) { subscription.magazine.create }

      it 'clears association on that side' do
        expect do
          subscription.magazine.delete
        end.to change { magazine.subscriptions.target }.from([subscription]).to([])
      end

      it 'persists changes on that side' do
        expect do
          subscription.magazine.delete
        end.to change { Magazine.find(magazine.title).subscriptions.target }.from([subscription]).to([])
      end
    end

    context 'has one' do
      let(:sponsor) { Sponsor.create }
      let!(:magazine) { sponsor.magazine.create }

      it 'clears association on that side' do
        expect do
          sponsor.magazine.delete
        end.to change { magazine.sponsor.target }.from(sponsor).to(nil)
      end

      it 'persists changes on that side' do
        expect do
          sponsor.magazine.delete
        end.to change { Magazine.find(magazine.title).sponsor.target }.from(sponsor).to(nil)
      end
    end
  end

  describe 'foreign_key option' do
    before do
      @directory_class = directory_class = new_class(table_name: :directories)

      @file_class = file_class = new_class(table_name: :files) do
        belongs_to :directory, class: directory_class, foreign_key: :directory_id

        def self.to_s
          'File'
        end
      end

      @directory_class.instance_eval do
        has_many :files, class: file_class

        def self.to_s
          'Directory'
        end
      end
    end

    it 'specifies field name' do
      file = @file_class.new
      expect(file.respond_to?(:directory_id)).to eq(true)
    end

    it 'forces to store :id as a scalar value and not as collection' do
      directory = @directory_class.create!
      file = @file_class.new(directory: directory)
      expect(file.directory_id).to eq(directory.id)
    end

    it 'assigns and persists id correctly on this side of association' do
      directory = @directory_class.create!
      file = @file_class.create!(directory: directory)

      expect(@file_class.find(file.id).directory_id).to eq(directory.id)
      expect(file.directory).to eq(directory)
      expect(@file_class.find(file.id).directory).to eq(directory)
    end

    it 'assigns and persists id correctly on the other side of association' do
      directory = @directory_class.create!
      file = @file_class.create!(directory: directory)

      expect(directory.files.to_a).to eq [file]
      expect(@directory_class.find(directory.id).files.to_a).to eq [file]
    end
  end
end
