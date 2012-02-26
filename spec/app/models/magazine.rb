class Magazine
  include Dynamoid::Document
  
  has_many :subscriptions
  has_one :sponsor
end