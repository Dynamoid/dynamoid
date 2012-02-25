class Magazine
  include Dynamoid::Document
  
  has_many :subscriptions
end