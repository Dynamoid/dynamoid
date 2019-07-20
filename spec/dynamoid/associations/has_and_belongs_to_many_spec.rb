# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Associations::HasAndBelongsToMany do
  let(:subscription) { Subscription.create }
  let(:camel_case) { CamelCase.create }

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

  describe 'assigning' do
    let(:subscription) { Subscription.create }
    let(:user) { User.create }

    it 'associates model on this side' do
      subscription.users << user
      expect(subscription.users.to_a).to eq([user])
    end

    it 'associates model on that side' do
      subscription.users << user
      expect(user.subscriptions.to_a).to eq([subscription])
    end
  end

  describe '#delete' do
    it 'clears association on this side' do
      subscription = Subscription.create
      user = subscription.users.create

      expect do
        subscription.users.delete(user)
      end.to change { subscription.users.target }.from([user]).to([])
    end

    it 'persists changes on this side' do
      subscription = Subscription.create
      user = subscription.users.create

      expect do
        subscription.users.delete(user)
      end.to change { Subscription.find(subscription.id).users.target }.from([user]).to([])
    end

    context 'has and belongs to many' do
      let(:subscription) { Subscription.create }
      let!(:user) { subscription.users.create }

      it 'clears association on that side' do
        expect do
          subscription.users.delete(user)
        end.to change { subscription.users.target }.from([user]).to([])
      end

      it 'persists changes on that side' do
        expect do
          subscription.users.delete(user)
        end.to change { Subscription.find(subscription.id).users.target }.from([user]).to([])
      end
    end
  end
end
