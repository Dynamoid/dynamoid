# frozen_string_literal: true

class Bar
  include Dynamoid::Document

  table name: :bar,
        key: :bar_id,
        read_capacity: 200,
        write_capacity:  200

  range :visited_at, :datetime
  field :name
  field :visited_at, :integer

  validates_presence_of :name, :visited_at

  global_secondary_index hash_key: :name, range_key: :visited_at
end
