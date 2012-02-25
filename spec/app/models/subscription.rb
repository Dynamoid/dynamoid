class Subscription
  include Dynamoid::Document
  
  belongs_to :magazine
end