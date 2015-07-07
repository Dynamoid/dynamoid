require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Finders do
  let!(:address) { Address.create(:city => 'Chicago') }

  it 'finds an existing address' do
    found = Address.find(address.id)

    expect(found).to eq address
    expect(found.city).to eq 'Chicago'
  end

  it 'is not a new object' do
    found = Address.find(address.id)

    expect(found.new_record).to be_falsey
  end

  it 'returns nil when nothing is found' do
    expect(Address.find('1234')).to be_nil
  end

  it 'finds multiple ids' do
    address2 = Address.create(:city => 'Illinois')

    expect(Set.new(Address.find(address.id, address2.id))).to eq Set.new([address, address2])
  end

  # TODO: ATM, adapter sets consistent read to be true for all query. Provide option for setting consistent_read option
  #it 'sends consistent option to the adapter' do
  #  expects(Dynamoid::Adapter).to receive(:get_item).with { |table_name, key, options| options[:consistent_read] == true }
  #  Address.find('x', :consistent_read => true)
  #end

  context 'with users' do
    before do
      User.create_indexes
    end

    it 'finds using method_missing for attributes' do
      array = Address.find_by_city('Chicago')

      expect(array).to eq address
    end

    it 'finds using method_missing for multiple attributes' do
      user = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com')

      expect(array).to eq [user]
    end

    it 'finds using method_missing for single attributes and multiple results' do
      user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      user2 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name('Josh')

      expect(array.size).to eq 2
      expect(array).to include user1
      expect(array).to include user2
    end

    it 'finds using method_missing for multiple attributes and multiple results' do
      user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      user2 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com')

      expect(array.size).to eq 2
      expect(array).to include user1
      expect(array).to include user2
    end

    it 'finds using method_missing for multiple attributes and no results' do
      user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      user2 = User.create(:name => 'Justin', :email => 'justin@joshsymonds.com')

      array = User.find_all_by_name_and_email('Gaga','josh@joshsymonds.com')

      expect(array).to be_empty
    end

    it 'finds using method_missing for a single attribute and no results' do
      user1 = User.create(:name => 'Josh', :email => 'josh@joshsymonds.com')
      user2 = User.create(:name => 'Justin', :email => 'justin@joshsymonds.com')

      array = User.find_all_by_name('Gaga')

      expect(array).to be_empty
    end

    it 'should find on a query that is not indexed' do
      user = User.create(:password => 'Test')

      array = User.find_all_by_password('Test')

      expect(array).to eq [user]
    end

    it 'should find on a query on multiple attributes that are not indexed' do
      user = User.create(:password => 'Test', :name => 'Josh')

      array = User.find_all_by_password_and_name('Test', 'Josh')

      expect(array).to eq [user]
    end

    it 'should return an empty array when fields exist but nothing is found' do
      array = User.find_all_by_password('Test')

      expect(array).to be_empty
    end

  end

  context 'find_all' do

    it 'should return a array of users' do
      users = (1..10).map { User.create }
      expect(User.find_all(users.map(&:id))).to match_array(users)
    end

    it 'should return a array of tweets' do
      tweets = (1..10).map { |i| Tweet.create(:tweet_id => "#{i}", :group => "group_#{i}") }
      expect(Tweet.find_all(tweets.map { |t| [t.tweet_id, t.group] })).to match_array(tweets)
    end

    it 'should return an empty array' do
      expect(User.find_all([])).to eq([])
    end

    it 'returns empty array when there are no results' do
      expect(Address.find_all('bad' + address.id.to_s)).to eq []
    end

    it 'passes options to the adapter' do
      pending "This test is broken as we are overriding the consistent_read option to true inside the adapter"
      user_ids = [%w(1 red), %w(1 green)]
      Dynamoid::Adapter.expects(:read).with(anything, user_ids, :consistent_read => true)
      User.find_all(user_ids, :consistent_read => true)
    end

  end
end
