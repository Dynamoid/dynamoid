class CamelCase
  include Dynamoid::Document

  field :color

  belongs_to :magazine
  has_many :users
  has_one :sponsor
  has_and_belongs_to_many :subscriptions

end
