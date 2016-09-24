class Magazine
  include Dynamoid::Document
  table :key => :title
  
  field :title
  
  has_many :subscriptions
  has_many :camel_cases
  has_one :sponsor

  belongs_to :owner, :class_name => 'User', :inverse_of => :books
end
