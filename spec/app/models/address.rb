class Address
  include Dynamoid::Document
  
  field :city
  field :options, :serialized
  field :deliverable, :boolean

  def zip_code=(zip_code)
    self.city = "Chicago"
  end
end
