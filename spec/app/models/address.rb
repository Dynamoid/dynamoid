class Address
  include Dynamoid::Document
  
  field :city
  field :options, :serialized
end
