# frozen_string_literal: true

class Sponsor
  include Dynamoid::Document

  belongs_to :magazine
  has_many :subscriptions

  belongs_to :camel_case
end
