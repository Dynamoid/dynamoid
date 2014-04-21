class Post
  include Dynamoid::Document

  table name: :posts, key: :post_id, read_capacity: 200, write_capacity:  200
  
  range :posted_at, :datetime

  field :body
end
