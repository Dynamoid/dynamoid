class Magazine
  include Dynamoid::Document
  
  field :title
  
  has_many :subscriptions
  has_one :sponsor
end