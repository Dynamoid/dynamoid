# frozen_string_literal: true

class Vehicle
  include Dynamoid::Document

  field :type

  field :description
end
