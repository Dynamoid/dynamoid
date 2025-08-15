# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.inc' do
    let(:document_class) do
      new_class do
        field :links_count, :integer
        field :mentions_count, :integer
      end
    end

    it 'adds specified value' do
      obj = document_class.create!(links_count: 2)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
    end

    it 'accepts negative value' do
      obj = document_class.create!(links_count: 10)

      expect {
        document_class.inc(obj.id, links_count: -2)
      }.to change { document_class.find(obj.id).links_count }.from(10).to(8)
    end

    it 'traits nil value as zero' do
      obj = document_class.create!(links_count: nil)

      expect {
        document_class.inc(obj.id, links_count: 5)
      }.to change { document_class.find(obj.id).links_count }.from(nil).to(5)
    end

    it 'supports passing several attributes at once' do
      obj = document_class.create!(links_count: 2, mentions_count: 31)
      document_class.inc(obj.id, links_count: 5, mentions_count: 9)

      expect(document_class.find(obj.id).links_count).to eql(7)
      expect(document_class.find(obj.id).mentions_count).to eql(40)
    end

    it 'accepts sort key if it is declared' do
      class_with_sort_key = new_class do
        range :author_name
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(author_name: 'Mike', links_count: 2)
      class_with_sort_key.inc(obj.id, 'Mike', links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of partition key to update item' do
      klass = new_class(partition_key: { name: :published_on, type: :date }) do
        field :links_count, :integer
      end

      obj = klass.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      klass.inc('2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'uses dumped value of sort key to update item' do
      class_with_sort_key = new_class do
        range :published_on, :date
        field :links_count, :integer
      end

      obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
      class_with_sort_key.inc(obj.id, '2018-10-07'.to_date, links_count: 5)

      expect(obj.reload.links_count).to eql(7)
    end

    it 'returns self' do
      obj = document_class.create!(links_count: 2)

      expect(document_class.inc(obj.id, links_count: 5)).to eq(document_class)
    end

    it 'updates `updated_at` attribute when touch: true option passed' do
      obj = document_class.create!(links_count: 2, updated_at: Time.now - 1.day)

      expect { document_class.inc(obj.id, links_count: 5) }.not_to change { document_class.find(obj.id).updated_at }
      expect { document_class.inc(obj.id, links_count: 5, touch: true) }.to change { document_class.find(obj.id).updated_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: name option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
      end

      obj = klass.create!(age: 21, viewed_at: Time.now - 1.day, updated_at: Time.now - 2.days)

      expect do
        expect do
          klass.inc(obj.id, links_count: 5, touch: :viewed_at)
        end.to change { klass.find(obj.id).updated_at }
      end.to change { klass.find(obj.id).viewed_at }
    end

    it 'updates `updated_at` and the specified attributes when touch: [<name>*] option passed' do
      klass = new_class do
        field :links_count, :integer
        field :viewed_at, :datetime
        field :tagged_at, :datetime
      end

      obj = klass.create!(
        age: 21,
        viewed_at: Time.now - 1.day,
        tagged_at: Time.now - 3.days,
        updated_at: Time.now - 2.days
      )

      expect do
        expect do
          expect do
            klass.inc(obj.id, links_count: 5, touch: %i[viewed_at tagged_at])
          end.to change { klass.find(obj.id).updated_at }
        end.to change { klass.find(obj.id).viewed_at }
      end.to change { klass.find(obj.id).tagged_at }
    end

    describe 'timestamps' do
      it 'does not change updated_at', config: { timestamps: true } do
        obj = document_class.create!
        expect(obj.updated_at).to be_present

        expect {
          document_class.inc(obj.id, links_count: 5)
        }.not_to change { document_class.find(obj.id).updated_at }
      end
    end

    describe 'type casting' do
      it 'uses casted value of sort key to call UpdateItem' do
        class_with_sort_key = new_class do
          range :published_on, :date
          field :links_count, :integer
        end

        obj = class_with_sort_key.create!(published_on: '2018-10-07'.to_date, links_count: 2)
        class_with_sort_key.inc(obj.id, '2018-10-07', links_count: 5)

        expect(obj.reload.links_count).to eql(7)
      end

      it 'type casts attributes' do
        obj = document_class.create!(links_count: 2)

        expect {
          document_class.inc(obj.id, links_count: '5.12345')
        }.to change { document_class.find(obj.id).links_count }.from(2).to(7)
      end
    end
  end
end
