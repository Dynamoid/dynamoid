class Vehicle
  include Dynamoid::Document
  
  field :type
  
  field :description
end