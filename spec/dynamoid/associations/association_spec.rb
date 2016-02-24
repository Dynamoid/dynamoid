require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Dynamoid::Associations::Association do

  it 'returns an empty array if there are no associations' do
    expect(Magazine.create.subscriptions).to be_empty
  end

  it 'adds an item to an association' do
    subscription = Subscription.create
    magazine = Magazine.create

    magazine.subscriptions << subscription

    expect(magazine.subscriptions.size).to eq 1
    expect(magazine.subscriptions).to include(subscription)
  end

  it 'deletes an item from an association' do
    subscription = Subscription.create
    magazine = Magazine.create

    magazine.subscriptions << subscription

    magazine.subscriptions.delete(subscription)
    expect(magazine.subscriptions.size).to eq 0
  end

  it 'creates an item from an association' do
    magazine = Magazine.create
    subscription = magazine.subscriptions.create

    expect(subscription.class).to eq Subscription
    expect(magazine.subscriptions.size).to eq 1
    expect(magazine.subscriptions).to include subscription
  end

  it 'returns the number of items in the association' do
    magazine = Magazine.create
    magazine.subscriptions.create
    expect(magazine.subscriptions.size).to eq 1

    second_subcription = magazine.subscriptions.create
    expect(magazine.subscriptions.size).to eq 2

    magazine.subscriptions.delete(second_subcription)
    expect(magazine.subscriptions.size).to eq 1

    magazine.subscriptions = []
    expect(magazine.subscriptions.size).to eq 0
  end

  it 'assigns directly via the equals operator' do
    magazine = Magazine.create
    subscription = Subscription.create
    magazine.subscriptions = [subscription]

    expect(magazine.subscriptions).to eq [subscription]
  end

  it 'assigns directly via the equals operator and reflects to the target association' do
    magazine = Magazine.create
    subscription = Subscription.create
    magazine.subscriptions = [subscription]

    expect(subscription.magazine).to eq magazine
  end

  it 'does not assign reflection association if the reflection association does not exist' do
    sponsor = Sponsor.create

    subscription = sponsor.subscriptions.create
    expect(subscription).not_to respond_to :sponsor
    expect(subscription).not_to respond_to :sponsors
    expect(subscription).not_to respond_to :sponsors_ids
    expect(subscription).not_to respond_to :sponsor_ids
  end

  it 'deletes all items from the association' do
    magazine = Magazine.create
    magazine.subscriptions << Subscription.create
    magazine.subscriptions << Subscription.create
    magazine.subscriptions << Subscription.create

    expect(magazine.subscriptions.size).to eq 3

    magazine.subscriptions = nil
    expect(magazine.subscriptions.size).to eq 0
  end

  it 'uses where inside an association and returns a result' do
    magazine = Magazine.create
    included_subscription = magazine.subscriptions.create(length: 10)
    unincldued_subscription = magazine.subscriptions.create(length: 8)

    expect(magazine.subscriptions.where(length: 10).all).to eq [included_subscription]
  end

  it 'uses where inside an association and returns an empty set' do
    magazine = Magazine.create
    included_subscription = magazine.subscriptions.create(length: 10)
    unincldued_subscription = magazine.subscriptions.create(length: 8)

    expect(magazine.subscriptions.where(length: 6).all).to be_empty
  end

  it 'includes enumerable' do
    magazine = Magazine.create
    subscription1 = magazine.subscriptions.create
    subscription2 = magazine.subscriptions.create
    subscription3 = magazine.subscriptions.create

    expect(magazine.subscriptions.collect(&:hash_key).sort).to eq [subscription1.hash_key, subscription2.hash_key, subscription3.hash_key].sort
  end

  it 'works for camel-cased associations' do
    expect(Magazine.create.camel_cases.create.class).to eq CamelCase
  end

  it 'destroys associations' do
    subscription = Subscription.create
    magazine = Magazine.create

    expect(magazine.subscriptions).to receive(:target).and_return([subscription])
    expect(subscription).to receive(:destroy)

    magazine.subscriptions.destroy_all
  end

  it 'deletes associations' do
    subscription = Subscription.new
    magazine = Magazine.create
    expect(magazine.subscriptions).to receive(:target).and_return([subscription])
    expect(subscription).to receive(:delete)

    magazine.subscriptions.delete_all
  end

  it 'replaces existing associations when using the setter' do
    magazine = Magazine.create
    subscription1 = magazine.subscriptions.create
    subscription2 = magazine.subscriptions.create
    subscription3 = Subscription.create

    expect(subscription1.reload.magazine_ids).to be_present
    expect(subscription2.reload.magazine_ids).to be_present

    magazine.subscriptions = subscription3
    expect(magazine.subscriptions_ids).to eq Set[subscription3.hash_key]

    expect(subscription1.reload.magazine_ids).to be_blank
    expect(subscription2.reload.magazine_ids).to be_blank
    expect(subscription3.reload.magazine_ids).to eq Set[magazine.id]
  end

  it 'destroys all objects and removes them from the association' do
    magazine = Magazine.create
    subscription1 = magazine.subscriptions.create
    subscription2 = magazine.subscriptions.create
    subscription3 = magazine.subscriptions.create

    magazine.subscriptions.destroy_all

    expect(magazine.subscriptions).to be_blank
    expect(Subscription.all).to be_empty
  end

  it 'deletes all objects and removes them from the association' do
    magazine = Magazine.create
    subscription1 = magazine.subscriptions.create
    subscription2 = magazine.subscriptions.create
    subscription3 = magazine.subscriptions.create

    magazine.subscriptions.delete_all

    expect(magazine.subscriptions).to be_blank
    expect(Subscription.all).to be_empty
  end

  it 'delegates class to the association object' do
    magazine = Magazine.create

    expect(magazine.sponsor.class).to eq nil.class
    magazine.sponsor.create
    expect(magazine.sponsor.class).to eq Sponsor

    expect(magazine.subscriptions.class).to eq Array
    magazine.subscriptions.create
    expect(magazine.subscriptions.class).to eq Array
  end

  it 'loads association one time only' do
    pending("FIXME: find_target doesn't exist anymore")
    magazine = Magazine.create
    sponsor = magazine.sponsor.create

    expect(magazine.sponsor).to receive(:find_target).once.and_return(sponsor)

    magazine.sponsor.id
    magazine.sponsor.id
  end

end
