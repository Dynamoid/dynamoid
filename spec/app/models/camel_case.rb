class CamelCase
  include Dynamoid::Document

  field :color

  belongs_to :magazine
end
