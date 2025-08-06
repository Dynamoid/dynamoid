# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Finders do
  describe '.find' do
    let(:klass) do
      new_class(class_name: 'Document')
    end

    let(:klass_with_composite_key) do
      new_class(class_name: 'Cat') do
        range :age, :integer
      end
    end

    context 'a single primary key provided' do
      context 'simple primary key' do
        it 'finds a model' do
          obj = klass.create!
          expect(klass.find(obj.id)).to eql(obj)
        end

        it 'raises RecordNotFound error when found nothing' do
          klass.create_table
          expect {
            klass.find('wrong-id')
          }.to raise_error(Dynamoid::Errors::RecordNotFound, "Couldn't find Document with primary key wrong-id")
        end
      end

      context 'composite primary key' do
        it 'finds a model' do
          obj = klass_with_composite_key.create!(age: 12)
          expect(klass_with_composite_key.find(obj.id, range_key: 12)).to eql(obj)
        end

        it 'raises RecordNotFound error when found nothing' do
          klass_with_composite_key.create_table
          expect {
            klass_with_composite_key.find('wrong-id', range_key: 100_500)
          }.to raise_error(Dynamoid::Errors::RecordNotFound, "Couldn't find Cat with primary key (wrong-id,100500)")
        end

        it 'raises MissingRangeKey when range key is not specified' do
          obj = klass_with_composite_key.create!(age: 12)

          expect {
            klass_with_composite_key.find(obj.id)
          }.to raise_error(Dynamoid::Errors::MissingRangeKey)
        end
      end

      it 'returns persisted? object' do
        obj = klass.create!
        expect(klass.find(obj.id)).to be_persisted
      end

      context 'field is not declared in document' do
        let(:class_with_not_declared_field) do
          new_class do
            field :name
          end
        end

        before do
          class_with_not_declared_field.create_table
        end

        it 'ignores it without exceptions' do
          Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', name: 'Alex', bod: '1996-12-21')
          obj = class_with_not_declared_field.find('1')

          expect(obj.id).to eql('1')
          expect(obj.name).to eql('Alex')
        end
      end

      describe 'raise_error option' do
        before do
          klass.create_table
        end

        context 'when true' do
          it 'leads to raising RecordNotFound exception if model not found' do
            expect do
              klass.find('blah-blah', raise_error: true)
            end.to raise_error(Dynamoid::Errors::RecordNotFound)
          end
        end

        context 'when false' do
          it 'leads to not raising exception if model not found' do
            expect(klass.find('blah-blah', raise_error: false)).to eq nil
          end
        end
      end

      it 'type casts a partition key value' do
        klass = new_class(partition_key: { name: :published_on, type: :date })

        obj = klass.create!(published_on: '2018-10-07'.to_date)
        expect(klass.find('2018-10-07')).to eql(obj)
      end

      it 'type casts a sort key value' do
        klass = new_class do
          range :published_on, :date
        end

        obj = klass.create!(published_on: '2018-10-07'.to_date)
        expect(klass.find(obj.id, range_key: '2018-10-07')).to eql(obj)
      end

      it 'uses dumped value of partition key' do
        klass = new_class(partition_key: { name: :published_on, type: :date })

        obj = klass.create!(published_on: '2018-10-07'.to_date)
        expect(klass.find(obj.published_on)).to eql(obj)
      end

      it 'uses dumped value of sort key' do
        klass = new_class do
          range :published_on, :date
        end

        obj = klass.create!(published_on: '2018-10-07'.to_date)
        expect(klass.find(obj.id, range_key: obj.published_on)).to eql(obj)
      end
    end

    context 'multiple primary keys provided' do
      context 'simple primary key' do
        it 'finds models with an array of keys' do
          objects = (1..2).map { klass.create! }
          obj1, obj2 = objects
          expect(klass.find([obj1.id, obj2.id])).to match_array(objects)
        end

        it 'finds with a list of keys' do
          objects = (1..2).map { klass.create! }
          obj1, obj2 = objects
          expect(klass.find(obj1.id, obj2.id)).to match_array(objects)
        end

        it 'finds with one key' do
          obj = klass.create!
          expect(klass.find([obj.id])).to eq([obj])
        end

        it 'returns an empty array if an empty array passed' do
          klass.create_table
          expect(klass.find([])).to eql([])
        end

        it 'raises RecordNotFound error when some objects are not found' do
          objects = (1..2).map { klass.create! }
          obj1, obj2 = objects

          expect {
            klass.find([obj1.id, obj2.id, 'wrong-id'])
          }.to raise_error(Dynamoid::Errors::RecordNotFound,
                           "Couldn't find all Documents with primary keys [#{obj1.id}, #{obj2.id}, wrong-id] (found 2 results, but was looking for 3)")
        end

        it 'raises RecordNotFound even if only one primary key provided and no result found' do
          klass.create_table

          expect {
            klass.find(['wrong-id'])
          }.to raise_error(Dynamoid::Errors::RecordNotFound,
                           "Couldn't find all Documents with primary keys [wrong-id] (found 0 results, but was looking for 1)")
        end
      end

      context 'composite primary key' do
        it 'finds with an array of keys' do
          objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
          obj1, obj2 = objects
          expect(klass_with_composite_key.find([[obj1.id, obj1.age], [obj2.id, obj2.age]])).to match_array(objects)
        end

        it 'finds with one key' do
          obj = klass_with_composite_key.create!(age: 12)
          expect(klass_with_composite_key.find([[obj.id, obj.age]])).to eq([obj])
        end

        it 'returns an empty array if an empty array passed' do
          klass_with_composite_key.create_table
          expect(klass_with_composite_key.find([])).to eql([])
        end

        it 'raises RecordNotFound error when some objects are not found' do
          obj = klass_with_composite_key.create!(age: 12)
          expect {
            klass_with_composite_key.find([[obj.id, obj.age], ['wrong-id', 100_500]])
          }.to raise_error(Dynamoid::Errors::RecordNotFound,
                           "Couldn't find all Cats with primary keys [(#{obj.id},12), (wrong-id,100500)] (found 1 results, but was looking for 2)")
        end

        it 'raises RecordNotFound if only one primary key provided and no result found' do
          klass_with_composite_key.create_table
          expect {
            klass_with_composite_key.find([['wrong-id', 100_500]])
          }.to raise_error(Dynamoid::Errors::RecordNotFound,
                           "Couldn't find all Cats with primary keys [(wrong-id,100500)] (found 0 results, but was looking for 1)")
        end

        it 'finds with a list of keys' do
          pending 'still is not implemented'

          objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
          obj1, obj2 = objects
          expect(klass_with_composite_key.find([obj1.id, obj1.age], [obj2.id, obj2.age])).to match_array(objects)
        end

        it 'raises MissingRangeKey when range key is not specified' do
          obj1, obj2 = klass_with_composite_key.create!([{ age: 1 }, { age: 2 }])

          expect {
            klass_with_composite_key.find([obj1.id, obj2.id])
          }.to raise_error(Dynamoid::Errors::MissingRangeKey)
        end
      end

      it 'returns persisted? objects' do
        objects = (1..2).map { |i| klass_with_composite_key.create!(age: i) }
        obj1, obj2 = objects

        objects = klass_with_composite_key.find([[obj1.id, obj1.age], [obj2.id, obj2.age]])
        obj1, obj2 = objects

        expect(obj1).to be_persisted
        expect(obj2).to be_persisted
      end

      describe 'raise_error option' do
        context 'when true' do
          it 'leads to raising exception if model not found' do
            obj = klass.create!

            expect do
              klass.find([obj.id, 'blah-blah'], raise_error: true)
            end.to raise_error(Dynamoid::Errors::RecordNotFound)
          end
        end

        context 'when false' do
          it 'leads to not raising exception if model not found' do
            obj = klass.create!
            expect(klass.find([obj.id, 'blah-blah'], raise_error: false)).to eq [obj]
          end
        end
      end

      it 'type casts a partition key value' do
        klass = new_class(partition_key: { name: :published_on, type: :date })
        obj1 = klass.create!(published_on: '2018-10-07'.to_date)
        obj2 = klass.create!(published_on: '2018-10-08'.to_date)

        objects = klass.find(%w[2018-10-07 2018-10-08])

        expect(objects).to contain_exactly(obj1, obj2)
      end

      it 'type casts a sort key value' do
        klass = new_class do
          range :published_on, :date
        end
        obj1 = klass.create!(published_on: '2018-10-07'.to_date)
        obj2 = klass.create!(published_on: '2018-10-08'.to_date)

        objects = klass.find([[obj1.id, '2018-10-07'], [obj2.id, '2018-10-08']])

        expect(objects).to contain_exactly(obj1, obj2)
      end

      it 'uses dumped value of partition key' do
        klass = new_class(partition_key: { name: :published_on, type: :date })
        obj1 = klass.create!(published_on: '2018-10-07'.to_date)
        obj2 = klass.create!(published_on: '2018-10-08'.to_date)

        objects = klass.find([obj1.published_on, obj2.published_on])

        expect(objects).to contain_exactly(obj1, obj2)
      end

      it 'uses dumped value of sort key' do
        klass = new_class do
          range :published_on, :date
        end
        obj1 = klass.create!(published_on: '2018-10-07'.to_date)
        obj2 = klass.create!(published_on: '2018-10-08'.to_date)

        objects = klass.find([[obj1.id, obj1.published_on], [obj2.id, obj2.published_on]])

        expect(objects).to contain_exactly(obj1, obj2)
      end

      context 'field is not declared in document' do
        let(:class_with_not_declared_field) do
          new_class do
            field :name
          end
        end

        before do
          class_with_not_declared_field.create_table
        end

        it 'ignores it without exceptions' do
          Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '1', dob: '1996-12-21')
          Dynamoid.adapter.put_item(class_with_not_declared_field.table_name, id: '2', dob: '2001-03-14')

          objects = class_with_not_declared_field.find(%w[1 2])

          expect(objects.size).to eql 2
          expect(objects.map(&:id)).to contain_exactly('1', '2')
        end
      end

      context 'backoff is specified' do
        before do
          @old_backoff = Dynamoid.config.backoff
          @old_backoff_strategies = Dynamoid.config.backoff_strategies.dup

          @counter = 0
          Dynamoid.config.backoff_strategies[:simple] = ->(_) { -> { @counter += 1 } }
          Dynamoid.config.backoff = { simple: nil }
        end

        after do
          Dynamoid.config.backoff = @old_backoff
          Dynamoid.config.backoff_strategies = @old_backoff_strategies
        end

        it 'returns items' do
          users = (1..10).map { User.create! }

          results = User.find(users.map(&:id))
          expect(results).to match_array(users)
        end

        it 'raise RecordNotFound error when there are no results' do
          User.create_table

          expect {
            User.find(['some-fake-id'])
          }.to raise_error(Dynamoid::Errors::RecordNotFound)
        end

        it 'uses specified backoff when some items are not processed' do
          # batch_get_item has following limitations:
          # * up to 100 items at once
          # * up to 16 MB at once
          #
          # So we write data as large as possible and read it back
          # 100 * 400 KB (limit for item) = ~40 MB
          # 40 MB / 16 MB = 3 times

          ids = (1..100).map(&:to_s)
          users = ids.map do |id|
            name = ' ' * (400.kilobytes - 120) # 400KB - length(attribute names)
            User.create!(id: id, name: name)
          end

          results = User.find(users.map(&:id))
          expect(results).to match_array(users)

          expect(@counter).to eq 2
        end

        it 'uses new backoff after successful call without unprocessed items' do
          skip 'it is difficult to test'
        end
      end
    end

    describe 'callbacks' do
      before do
        ScratchPad.record []
      end

      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          after_initialize { ScratchPad << 'run after_initialize' }
        end
        object = klass_with_callback.create!

        ScratchPad.record []
        klass_with_callback.find(object.id)

        expect(ScratchPad.recorded).to eql(['run after_initialize'])
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          after_find { ScratchPad << 'run after_find' }
        end
        object = klass_with_callback.create!

        ScratchPad.record []
        klass_with_callback.find(object.id)

        expect(ScratchPad.recorded).to eql(['run after_find'])
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          after_initialize { ScratchPad << 'run after_initialize' }
          after_find { ScratchPad << 'run after_find' }
        end
        object = klass_with_callback.create!

        ScratchPad.record []
        klass_with_callback.find(object.id)

        expect(ScratchPad.recorded).to eql(['run after_initialize', 'run after_find'])
      end
    end
  end

  it 'sends consistent option to the adapter' do
    address = Address.create!(city: 'Chicago')

    expect(Dynamoid.adapter).to receive(:get_item)
      .with(anything, anything, hash_including(consistent_read: true))
      .and_call_original
    Address.find(address.id, consistent_read: true)
  end

  context 'with users' do
    it 'finds using method_missing for attributes' do
      address = Address.create!(city: 'Chicago')
      array = Address.find_by_city('Chicago')

      expect(array).to eq address
    end

    it 'finds using method_missing for multiple attributes' do
      user = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com').to_a

      expect(array).to eq [user]
    end

    it 'finds using method_missing for single attributes and multiple results' do
      user1 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')
      user2 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')

      array = User.find_all_by_name('Josh').to_a

      expect(array.size).to eq 2
      expect(array).to include user1
      expect(array).to include user2
    end

    it 'finds using method_missing for multiple attributes and multiple results' do
      user1 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')
      user2 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')

      array = User.find_all_by_name_and_email('Josh', 'josh@joshsymonds.com').to_a

      expect(array.size).to eq 2
      expect(array).to include user1
      expect(array).to include user2
    end

    it 'finds using method_missing for multiple attributes and no results' do
      user1 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')
      user2 = User.create!(name: 'Justin', email: 'justin@joshsymonds.com')

      array = User.find_all_by_name_and_email('Gaga', 'josh@joshsymonds.com').to_a

      expect(array).to be_empty
    end

    it 'finds using method_missing for a single attribute and no results' do
      user1 = User.create!(name: 'Josh', email: 'josh@joshsymonds.com')
      user2 = User.create!(name: 'Justin', email: 'justin@joshsymonds.com')

      array = User.find_all_by_name('Gaga').to_a

      expect(array).to be_empty
    end

    it 'finds on a query that is not indexed' do
      user = User.create!(password: 'Test')

      array = User.find_all_by_password('Test').to_a

      expect(array).to eq [user]
    end

    it 'finds on a query on multiple attributes that are not indexed' do
      user = User.create!(password: 'Test', name: 'Josh')

      array = User.find_all_by_password_and_name('Test', 'Josh').to_a

      expect(array).to eq [user]
    end

    it 'returns an empty array when fields exist but nothing is found' do
      User.create_table
      array = User.find_all_by_password('Test').to_a

      expect(array).to be_empty
    end
  end

  context 'find_all' do
    it 'passes options to the adapter' do
      pending 'This test is broken as we are overriding the consistent_read option to true inside the adapter'
      user_ids = [%w[1 red], %w[1 green]]
      Dynamoid.adapter.expects(:read).with(anything, user_ids, consistent_read: true)
      User.find_all(user_ids, consistent_read: true)
    end

    describe 'callbacks' do
      it 'runs after_initialize callback' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
        end

        object = klass_with_callback.create!

        expect { klass_with_callback.find_all([object.id]) }.to output('run after_initialize').to_stdout
      end

      it 'runs after_find callback' do
        klass_with_callback = new_class do
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect { klass_with_callback.find_all([object.id]) }.to output('run after_find').to_stdout
      end

      it 'runs callbacks in the proper order' do
        klass_with_callback = new_class do
          after_initialize { print 'run after_initialize' }
          after_find { print 'run after_find' }
        end

        object = klass_with_callback.create!

        expect do
          klass_with_callback.find_all([object.id])
        end.to output('run after_initializerun after_find').to_stdout
      end
    end
  end

  describe '.find_all_by_secondary_index' do
    def time_to_decimal(time)
      BigDecimal(format('%d.%09d', time.to_i, time.nsec))
    end

    it 'returns exception if index could not be found' do
      Post.create!(post_id: 1, posted_at: Time.now)
      expect do
        Post.find_all_by_secondary_index(posted_at: Time.now.to_i)
      end.to raise_exception(Dynamoid::Errors::MissingIndex)
    end

    context 'local secondary index' do
      it 'queries the local secondary index' do
        time = DateTime.now
        p1 = Post.create!(name: 'p1', post_id: 1, posted_at: time)
        p2 = Post.create!(name: 'p2', post_id: 1, posted_at: time + 1.day)
        p3 = Post.create!(name: 'p3', post_id: 2, posted_at: time)

        posts = Post.find_all_by_secondary_index(
          { post_id: p1.post_id },
          range: { name: 'p1' }
        )
        post = posts.first

        expect(posts.count).to eql 1
        expect(post.name).to eql 'p1'
        expect(post.post_id).to eql '1'
      end
    end

    context 'global secondary index' do
      it 'can sort' do
        time = DateTime.now
        first_visit = Bar.create!(name: 'Drank', visited_at: (time - 1.day).to_i)
        Bar.create!(name: 'Drank', visited_at: time.to_i)
        last_visit = Bar.create!(name: 'Drank', visited_at: (time + 1.day).to_i)

        bars = Bar.find_all_by_secondary_index(
          { name: 'Drank' }, range: { 'visited_at.lte': (time + 10.days).to_i }
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
        first_visit = Bar.create!(name: 'Drank', visited_at: time - 1.day)
        Bar.create!(name: 'Drank', visited_at: time)
        last_visit = Bar.create!(name: 'Drank', visited_at: time + 1.day)
        different_bar = Bar.create!(name: 'Junk', visited_at: time + 7.days)
        bars = Bar.find_all_by_secondary_index(
          { name: 'Drank' }, range: { 'visited_at.lte': (time + 10.days).to_i },
                             scan_index_forward: false
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
        p1 = Post.create!(post_id: 1, posted_at: time, length: '10')
        p2 = Post.create!(post_id: 2, posted_at: time, length: '30')
        p3 = Post.create!(post_id: 3, posted_at: time, length: '10')

        posts = Post.find_all_by_secondary_index(length: '10')
        expect(posts.map(&:post_id).sort).to eql %w[1 3]
      end

      it 'queries gsi with hash and range key' do
        time = Time.now
        p1 = Post.create!(post_id: 1, posted_at: time, name: 'post1')
        p2 = Post.create!(post_id: 2, posted_at: time + 1.day, name: 'post1')
        p3 = Post.create!(post_id: 3, posted_at: time, name: 'post3')

        posts = Post.find_all_by_secondary_index(
          { name: 'post1' },
          range: { posted_at: time_to_decimal(time) }
        )
        expect(posts.map(&:post_id).sort).to eql ['1']
      end
    end

    describe 'custom range queries' do
      describe 'string comparisons' do
        it 'filters based on begins_with operator' do
          time = DateTime.now
          Post.create!(post_id: 1, posted_at: time, name: 'fb_post')
          Post.create!(post_id: 1, posted_at: time + 1.day, name: 'blog_post')

          posts = Post.find_all_by_secondary_index(
            { post_id: '1' }, range: { 'name.begins_with': 'blog_' }
          )
          expect(posts.map(&:name)).to eql ['blog_post']
        end
      end

      describe 'numeric comparisons' do
        before do
          @time = DateTime.now
          p1 = Post.create!(post_id: 1, posted_at: @time, name: 'post')
          p2 = Post.create!(post_id: 2, posted_at: @time + 1.day, name: 'post')
          p3 = Post.create!(post_id: 3, posted_at: @time + 2.days, name: 'post')
        end

        it 'filters based on gt (greater than)' do
          posts = Post.find_all_by_secondary_index(
            { name: 'post' },
            range: { 'posted_at.gt': time_to_decimal(@time + 1.day) }
          )
          expect(posts.map(&:post_id).sort).to eql ['3']
        end

        it 'filters based on lt (less than)' do
          posts = Post.find_all_by_secondary_index(
            { name: 'post' },
            range: { 'posted_at.lt': time_to_decimal(@time + 1.day) }
          )
          expect(posts.map(&:post_id).sort).to eql ['1']
        end

        it 'filters based on gte (greater than or equal to)' do
          posts = Post.find_all_by_secondary_index(
            { name: 'post' },
            range: { 'posted_at.gte': time_to_decimal(@time + 1.day) }
          )
          expect(posts.map(&:post_id).sort).to eql %w[2 3]
        end

        it 'filters based on lte (less than or equal to)' do
          posts = Post.find_all_by_secondary_index(
            { name: 'post' },
            range: { 'posted_at.lte': time_to_decimal(@time + 1.day) }
          )
          expect(posts.map(&:post_id).sort).to eql %w[1 2]
        end

        it 'filters based on between operator' do
          between = [time_to_decimal(@time - 1.day), time_to_decimal(@time + 1.5.day)]
          posts = Post.find_all_by_secondary_index(
            { name: 'post' },
            range: { 'posted_at.between': between }
          )
          expect(posts.map(&:post_id).sort).to eql %w[1 2]
        end
      end
    end
  end
end
