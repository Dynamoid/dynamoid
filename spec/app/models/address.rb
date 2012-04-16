class Address
  include Dynamoid::Document
  
  field :city
  field :options, :serialized

  def zip_code=(zip_code)
    self.city = "Chicago"
  end
end
