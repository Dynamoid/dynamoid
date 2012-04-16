class Tweet
  include Dynamoid::Document

  range :group, :string

  field :msg
end
