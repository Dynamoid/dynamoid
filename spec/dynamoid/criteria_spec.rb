# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Criteria do
  it 'supports querying with .where method' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }, { name: 'Alex' }])
    expect(klass.where(name: 'Alex')).to contain_exactly(objects[0], objects[2])
  end

  it 'supports combining .where and .first methods' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])
    expect(klass.where(name: 'Alex').first).to eq objects[0]
  end

  it 'supports combining .where and .last methods' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])
    expect(klass.where(name: 'Bob').last).to eq objects[1]
  end

  it 'supports combining .where and .all methods' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }, { name: 'Alex' }])
    expect(klass.where(name: 'Alex').all.to_a).to contain_exactly(objects[0], objects[2])
  end

  it 'supports querying with .all method' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])
    expect(klass.all).to match_array(objects)
  end

  it 'supports querying with .first method' do
    klass = new_class do
      range :name
    end

    object = klass.create(name: 'Alex')
    expect(klass.first).to eq object
  end

  it 'supports querying with .last method' do
    klass = new_class do
      range :name
    end

    object = klass.create(name: 'Alex')
    expect(klass.last).to eq object
  end

  it 'supports querying with .each method' do
    klass = new_class do
      range :name
    end
    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])

    result = []
    klass.each { |obj| result << obj } # rubocop:disable Style/MapIntoArray

    expect(result).to match_array(objects)
  end

  it 'supports querying with .record_limit method' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])
    actual = klass.record_limit(1).all.to_a

    expect(actual.size).to eq 1
    expect(actual[0]).to satisfy { |v| %w[Alex Bob].include?(v.name) }
  end

  it 'supports querying with .scan_limit method' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }])
    actual = klass.scan_limit(1).all.to_a

    expect(actual.size).to eq 1
    expect(actual[0]).to satisfy { |v| %w[Alex Bob].include?(v.name) }
  end

  it 'supports querying with .batch method' do
    klass = new_class do
      field :name
    end

    objects = klass.create([{ name: 'Alex' }, { name: 'Bob' }, { name: 'Alex' }])
    expect(klass.batch(2).all).to match_array(objects)
  end

  it 'supports querying with .start method' do
    klass = new_class do
      table key: :age
      range :name
      field :age, :integer
    end

    objects = klass.create([{ age: 20, name: 'Alex' }, { age: 20, name: 'Bob' }, { age: 20, name: 'Michael' }])

    actual = klass.start(objects[0]).all.to_a
    expect(actual).to eq objects[1..2]
  end

  it 'supports querying with .scan_index_forward method' do
    klass = new_class do
      table key: :age
      range :name
      field :age, :integer
    end

    objects = klass.create([{ age: 20, name: 'Alex' }, { age: 20, name: 'Bob' }, { age: 20, name: 'Michael' }])

    # force Query with age: 20 partition key condition
    actual = klass.scan_index_forward(true).where(age: 20).all.to_a
    expect(actual).to eq objects

    # force Query with age: 20 partition key condition
    actual = klass.scan_index_forward(false).where(age: 20).all.to_a
    expect(actual).to eq objects.reverse
  end

  it 'supports querying with .find_by_pages method' do
    klass = new_class
    objects = klass.create([{}, {}, {}])

    pages = []
    klass.find_by_pages do |models, _options|
      pages << models # actually there is only one page
    end

    expect(pages.flatten).to match_array(objects)
  end

  it 'supports querying with .project method' do
    klass = new_class do
      field :age, :integer
      field :name, :string
    end
    klass.create(age: 20, name: 'Alex')

    objects_with_name = klass.project(:name).to_a
    expect(objects_with_name.size).to eq 1

    object_with_name = objects_with_name[0]
    expect(object_with_name.name).to eq 'Alex'
    expect(object_with_name.age).to eq nil
  end

  it 'supports querying with .pluck method' do
    klass = new_class do
      field :age, :integer
      field :name, :string
    end

    klass.create([{ age: 20, name: 'Alex' }, { age: 20, name: 'Bob' }])
    expect(klass.pluck(:name)).to contain_exactly('Alex', 'Bob')
  end

  it 'supports querying with .consistent method' do
    klass = new_class do
      field :age, :integer
    end

    objects = klass.create([{ age: 20 }, { age: 30 }])
    actual = klass.consistent.all.to_a
    expect(actual).to match_array(objects)
  end

  it 'supports .delete_all method' do
    klass = new_class do
      field :age, :integer
    end

    objects = klass.create([{ age: 20 }, { age: 30 }])
    expect { klass.delete_all }.to change { klass.all.to_a.size }.from(2).to(0)
  end

  it 'supports .destroy_all method' do
    klass = new_class do
      field :age, :integer
    end

    objects = klass.create([{ age: 20 }, { age: 30 }])
    expect { klass.destroy_all }.to change { klass.all.to_a.size }.from(2).to(0)
  end

  context 'when scans using non-indexed fields and warn_on_scan config option is true' do
    it 'logs warnings', config: { warn_on_scan: true } do
      klass = new_class(partition_key: :id) do
        field :name
        field :password

        def self.to_s
          'User'
        end
      end
      klass.create_table

      expect(Dynamoid.logger).to receive(:warn).with('Queries without an index are forced to use scan and are generally much slower than indexed queries!')
      expect(Dynamoid.logger).to receive(:warn).with('You can index this query by adding index declaration to user.rb:')
      expect(Dynamoid.logger).to receive(:warn).with("* global_secondary_index hash_key: 'some-name', range_key: 'some-another-name'")
      expect(Dynamoid.logger).to receive(:warn).with("* local_secondary_index range_key: 'some-name'")
      expect(Dynamoid.logger).to receive(:warn).with('Not indexed attributes: :name, :password')

      klass.where(name: 'x', password: 'password').all
    end
  end

  context 'when scans using non-indexed fields and error_on_scan config option is true' do
    it 'raises an error', config: { error_on_scan: true } do
      klass = new_class(partition_key: :id) do
        field :name
        field :password
      end
      klass.create_table

      expect {
        klass.where(name: 'x', password: 'password').all
      }.to raise_error(Dynamoid::Errors::ScanProhibited)
    end
  end

  context 'when doing intentional, full-table scan (query is empty) and warn_on_scan config option is true' do
    it 'does not log any warnings', config: { warn_on_scan: true } do
      klass = new_class
      klass.create_table
      expect(Dynamoid.logger).not_to receive(:warn)

      klass.all
    end
  end

  context 'when doing intentional, full-table scan (query is empty) and error_on_scan config option is true' do
    it 'does not raise an error', config: { error_on_scan: true } do
      klass = new_class
      klass.create_table

      expect(klass.all.to_a).to eq []
    end
  end
end
