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

  it 'returns array if passed in array' do
    expect(Address.find([address.id])).to eq [address]
  end

  it 'returns object if non array id is passed in' do
    expect(Address.find(address.id)).to eq address
  end

  it 'returns nil if non-array id is passed in and no result found' do
    expect(Address.find("not existing id")).to be_nil
  end

  it 'returns empty array if array of ids is passed in and no result found' do
    expect(Address.find(["not existing id"])).to eq []
  end

  # TODO: ATM, adapter sets consistent read to be true for all query. Provide option for setting consistent_read option
  #it 'sends consistent option to the adapter' do
  #  expects(Dynamoid::Adapter).to receive(:get_item).with { |table_name, key, options| options[:consistent_read] == true }
  #  Address.find('x', :consistent_read => true)
  #end

  context 'with users' do
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
      User.create_table
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
      Dynamoid.adapter.expects(:read).with(anything, user_ids, :consistent_read => true)
      User.find_all(user_ids, :consistent_read => true)
    end

  end


  describe '.find_all_by_secondary_index' do
    def time_to_f(time)
      time.to_time.to_f
    end

    it 'returns exception if index could not be found' do
      Post.create(:post_id => 1, :posted_at => Time.now)
      expect do
        Post.find_all_by_secondary_index(:posted_at => Time.now.to_i)
      end.to raise_exception(Dynamoid::Errors::MissingIndex)
    end

    context 'local secondary index' do
      it 'queries the local secondary index' do
        time = DateTime.now
        p1 = Post.create(:name => "p1", :post_id => 1, :posted_at => time)
        p2 = Post.create(:name => "p2", :post_id => 1, :posted_at => time + 1.day)
        p3 = Post.create(:name => "p3", :post_id => 2, :posted_at => time)

        posts = Post.find_all_by_secondary_index(
          {:post_id => p1.post_id},
          :range => {:name => "p1"}
        )
        post = posts.first

        expect(posts.count).to eql 1
        expect(post.name).to eql "p1"
        expect(post.post_id).to eql "1"
      end
    end

    context 'global secondary index' do
      it 'can sort' do
        time = DateTime.now
        first_visit = Bar.create(:name => "Drank", :visited_at => (time - 1.day).to_i)
        Bar.create(:name => "Drank", :visited_at => time.to_i)
        last_visit = Bar.create(:name => "Drank", :visited_at => (time + 1.day).to_i)

        bars = Bar.find_all_by_secondary_index(
            {:name => "Drank"}, :range => {"visited_at.lte" => (time + 10.days).to_i}
        )
        first_bar = bars.first
        last_bar = bars.last
        expect(bars.count).to eql 3
        expect(first_bar.name).to eql first_visit.name
        expect(first_bar.bar_id).to eql first_visit.bar_id
        expect(last_bar.name).to eql last_visit.name
        expect(last_bar.bar_id).to eql last_visit.bar_id
      end
      it 'honors :scan_index_forward => false' do
        time = DateTime.now
        first_visit = Bar.create(:name => "Drank", :visited_at => time - 1.day)
        Bar.create(:name => "Drank", :visited_at => time)
        last_visit = Bar.create(:name => "Drank", :visited_at => time + 1.day)
        different_bar = Bar.create(:name => "Junk", :visited_at => time + 7.days)
        bars = Bar.find_all_by_secondary_index(
            {:name => "Drank"}, :range => {"visited_at.lte" => (time + 10.days).to_i},
            :scan_index_forward => false
        )
        first_bar = bars.first
        last_bar = bars.last
        expect(bars.count).to eql 3
        expect(first_bar.name).to eql last_visit.name
        expect(first_bar.bar_id).to eql last_visit.bar_id
        expect(last_bar.name).to eql first_visit.name
        expect(last_bar.bar_id).to eql first_visit.bar_id
      end
      it 'queries gsi with hash key' do
        time = DateTime.now
        p1 = Post.create(:post_id => 1, :posted_at => time, :length => "10")
        p2 = Post.create(:post_id => 2, :posted_at => time, :length => "30")
        p3 = Post.create(:post_id => 3, :posted_at => time, :length => "10")

        posts = Post.find_all_by_secondary_index(:length => "10")
        expect(posts.map(&:post_id).sort).to eql ["1", "3"]
      end

      it 'queries gsi with hash and range key' do
        time = DateTime.now
        p1 = Post.create(:post_id => 1, :posted_at => time, :name => "post1")
        p2 = Post.create(:post_id => 2, :posted_at => time + 1.day, :name => "post1")
        p3 = Post.create(:post_id => 3, :posted_at => time, :name => "post3")

        posts = Post.find_all_by_secondary_index(
          {:name => "post1"},
          :range =>  {:posted_at => time_to_f(time)}
        )
        expect(posts.map(&:post_id).sort).to eql ["1"]
      end
    end

    describe 'custom range queries' do
      describe 'string comparisons' do
        it 'filters based on begins_with operator' do
          time = DateTime.now
          Post.create(:post_id => 1, :posted_at => time, :name => "fb_post")
          Post.create(:post_id => 1, :posted_at => time + 1.day, :name => "blog_post")

          posts = Post.find_all_by_secondary_index(
            {:post_id => "1"}, :range => {"name.begins_with" => "blog_"}
          )
          expect(posts.map(&:name)).to eql ["blog_post"]
        end
      end

      describe 'numeric comparisons' do
        before(:each) do
          @time = DateTime.now
          p1 = Post.create(:post_id => 1, :posted_at => @time, :name => "post")
          p2 = Post.create(:post_id => 2, :posted_at => @time + 1.day, :name => "post")
          p3 = Post.create(:post_id => 3, :posted_at => @time + 2.days, :name => "post")
        end

        it 'filters based on gt (greater than)' do
          posts = Post.find_all_by_secondary_index(
            {:name => "post"},
            :range => {"posted_at.gt" => time_to_f(@time + 1.day)}
          )
          expect(posts.map(&:post_id).sort).to eql ["3"]
        end

        it 'filters based on lt (less than)' do
          posts = Post.find_all_by_secondary_index(
            {:name => "post"},
            :range => {"posted_at.lt" => time_to_f(@time + 1.day)}
          )
          expect(posts.map(&:post_id).sort).to eql ["1"]
        end

        it 'filters based on gte (greater than or equal to)' do
          posts = Post.find_all_by_secondary_index(
            {:name => "post"},
            :range => {"posted_at.gte" => time_to_f(@time + 1.day)}
          )
          expect(posts.map(&:post_id).sort).to eql ["2", "3"]
        end

        it 'filters based on lte (less than or equal to)' do
          posts = Post.find_all_by_secondary_index(
            {:name => "post"},
            :range => {"posted_at.lte" => time_to_f(@time + 1.day)}
          )
          expect(posts.map(&:post_id).sort).to eql ["1", "2"]
        end

        it 'filters based on between operator' do
          between = [time_to_f(@time - 1.day), time_to_f(@time + 1.5.day)]
          posts = Post.find_all_by_secondary_index(
            {:name => "post"},
            :range => {"posted_at.between" => between}
          )
          expect(posts.map(&:post_id).sort).to eql ["1", "2"]
        end
      end
    end
  end
end
