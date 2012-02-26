class User
  include Dynamoid::Document
  
  field :name
  field :email
  field :password
  
  index :name
  index :email
  index [:name, :email]
  
  has_and_belongs_to_many :subscriptions
end