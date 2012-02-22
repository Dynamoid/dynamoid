class User
  include Dynamoid::Document
  
  field :name
  field :email
  field :password
  
  index :name
  index :email
  index [:name, :email]
end