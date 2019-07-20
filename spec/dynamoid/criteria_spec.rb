# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Criteria do
  let!(:user1) { User.create(name: 'Josh', email: 'josh@joshsymonds.com', admin: true) }
  let!(:user2) { User.create(name: 'Justin', email: 'justin@joshsymonds.com', admin: false) }

  it 'finds first using where' do
    expect(User.where(name: 'Josh').first).to eq user1
  end

  it 'finds last using where' do
    expect(User.where(admin: false).last).to eq user2
  end

  it 'finds all using where' do
    expect(User.where(name: 'Josh').all.to_a).to eq [user1]
  end

  it 'returns all records' do
    expect(Set.new(User.all)).to eq Set.new([user1, user2])
    expect(User.all.first.new_record).to be_falsey
  end

  context 'Magazine table' do
    before(:each) do
      Magazine.create_table
    end

    it 'returns empty attributes for where' do
      expect(Magazine.where(title: 'Josh').all.to_a).to eq []
    end

    it 'returns empty attributes for all' do
      expect(Magazine.all.to_a).to eq []
    end
  end

  it 'passes each to all members' do
    expect { |b| User.each(&b)}.to yield_successive_args(
      be_kind_of(User).and(have_attributes('new_record' => false)),
      be_kind_of(User).and(have_attributes('new_record' => false))
    )
  end

  it 'passes find_by_pages to all members' do
    expect {|b| User.find_by_pages(&b)}.to yield_successive_args(
      [all(be_kind_of(User)), {last_evaluated_key: nil}],
    )
  end

  it 'returns a last_evaluated_key which may be used to restart iteration' do
    # Creates exactly 2 full pages
    58.times { User.create(name: SecureRandom.uuid * 1024) }

    first_page, first_page_meta = User.find_by_pages.first
    second_page, = User.start(first_page_meta[:last_evaluated_key]).find_by_pages.first

    expect(first_page & second_page).to be_empty
  end

  it 'returns N records' do
    5.times { |i| User.create(name: 'Josh', email: "josh_#{i}@joshsymonds.com") }
    expect(User.record_limit(2).all.count).to eq(2)
  end

  # TODO: This test is broken using the AWS SDK adapter.
  # it 'start with a record' do
  #  5.times { |i| User.create(:name => 'Josh', :email => 'josh_#{i}@joshsymonds.com') }
  #  all = User.all
  #  User.start(all[3]).all.should eq(all[4..-1])
  #
  #  all = User.where(:name => 'Josh').all
  #  User.where(:name => 'Josh').start(all[3]).all.should eq(all[4..-1])
  # end

  it 'send consistent option to adapter' do
    pending 'This test is broken as we are overriding the consistent_read option to true inside the adapter'
    expect(Dynamoid::Adapter).to receive(:get_item) { |_table_name, _key, options| options[:consistent_read] == true }
    User.where(name: 'x').consistent.first

    expect(Dynamoid::Adapter).to receive(:query) { |_table_name, options| options[:consistent_read] == true }.returns([])
    Tweet.where(tweet_id: 'xx', group: 'two').consistent.all

    expect(Dynamoid::Adapter).to receive(:query) { |_table_name, options| options[:consistent_read] == false }.returns([])
    Tweet.where(tweet_id: 'xx', group: 'two').all
  end

  it 'does not raise exception when consistent_read is used with scan' do
    expect do
      User.where(password: 'password').consistent.first
    end.not_to raise_error(Dynamoid::Errors::InvalidQuery)
  end

  context 'when scans using non-indexed fields and warn_on_scan config option is true' do
    before do
      @warn_on_scan = Dynamoid::Config.warn_on_scan
      Dynamoid::Config.warn_on_scan = true
    end
    after do
      Dynamoid::Config.warn_on_scan = @warn_on_scan
    end

    it 'logs warnings' do
      expect(Dynamoid.logger).to receive(:warn).with('Queries without an index are forced to use scan and are generally much slower than indexed queries!')
      expect(Dynamoid.logger).to receive(:warn).with('You can index this query by adding index declaration to user.rb:')
      expect(Dynamoid.logger).to receive(:warn).with("* global_secondary_index hash_key: 'some-name', range_key: 'some-another-name'")
      expect(Dynamoid.logger).to receive(:warn).with("* local_secondary_index range_key: 'some-name'")
      expect(Dynamoid.logger).to receive(:warn).with('Not indexed attributes: :name, :password')

      User.where(name: 'x', password: 'password').all
    end
  end
  context 'when doing intentional, full-table scan (query is empty) and warn_on_scan config option is true' do
    before do
      @warn_on_scan = Dynamoid::Config.warn_on_scan
      Dynamoid::Config.warn_on_scan = true
    end
    after do
      Dynamoid::Config.warn_on_scan = @warn_on_scan
    end

    it 'does not log any warnings' do
      expect(Dynamoid.logger).not_to receive(:warn)

      User.all
    end
  end
end
