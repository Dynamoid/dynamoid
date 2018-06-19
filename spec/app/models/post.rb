# frozen_string_literal: true

class Post
  include Dynamoid::Document

  table name: :posts, key: :post_id, read_capacity: 200, write_capacity: 200

  range :posted_at, :datetime

  field :body
  field :length
  field :name

  local_secondary_index range_key: :name
  global_secondary_index hash_key: :name, range_key: :posted_at
  global_secondary_index hash_key: :length
end
