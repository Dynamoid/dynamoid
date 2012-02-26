class Sponsor
  include Dynamoid::Document
  
  belongs_to :magazine
  has_many :subscriptions
end