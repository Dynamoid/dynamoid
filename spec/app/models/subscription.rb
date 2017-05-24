class Subscription
  include Dynamoid::Document
  table :key => :subs_id
  
  field :length, :integer

  belongs_to :magazine
  has_and_belongs_to_many :users

  belongs_to :customer, :class_name => 'User', :inverse_of => :monthly

  has_and_belongs_to_many :camel_cases
end
