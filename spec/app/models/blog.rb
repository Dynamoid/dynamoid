# frozen_string_literal: true

class Blog
  include Dynamoid::Document

  table name: :blogs, key: :hash_key

  field :title
  field :content
  field :likes, :integer
end
