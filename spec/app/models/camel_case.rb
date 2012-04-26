class CamelCase
  include Dynamoid::Document

  field :color

  belongs_to :magazine
  has_many :users
  has_one :sponsor
  has_and_belongs_to_many :subscriptions
  
  before_create :doing_before_create
  after_create :doing_after_create
  
  private
  
  def doing_before_create
    true
  end
  
  def doing_after_create
    true
  end

end
