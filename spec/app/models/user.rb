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

  has_many :books, :class_name => 'Magazine', :inverse_of => :owner
  has_one :monthly, :class_name => 'Subscription', :inverse_of => :customer

  has_and_belongs_to_many :followers, :class_name => 'User', :inverse_of => :following
  has_and_belongs_to_many :following, :class_name => 'User', :inverse_of => :followers

end
