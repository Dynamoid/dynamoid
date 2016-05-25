class Bar
  include Dynamoid::Document

  table name: :bar,
        key: :bar_id,
        range_key: :visited_at,
        read_capacity: 200,
        write_capacity:  200

  field :name
  field :visited_at, :integer

  validates_presence_of :name, :visited_at

  global_secondary_index :hash_key => :name, :range_key => :visited_at
end
