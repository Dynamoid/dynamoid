class User
  include Dynamoid::Document
  
  field :name
  field :email
  field :password
  field :last_logged_in_at, :datetime
  
  index :name
  index :email
  index [:name, :email]
  index :name, :range_key => :created_at
  index :name, :range_key => :last_logged_in_at
  index :created_at, :range => true
  
  has_and_belongs_to_many :subscriptions
end
