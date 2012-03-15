class Magazine
  include Dynamoid::Document
  
  field :title
  
  has_many :subscriptions
  has_many :camel_cases
  has_one :sponsor
end
