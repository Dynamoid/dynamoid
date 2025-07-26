# frozen_string_literal: true

class Magazine
  include Dynamoid::Document

  table key: :title

  field :title
  field :size, :number

  has_many :subscriptions
  has_many :camel_cases
  has_one :sponsor

  belongs_to :owner, class_name: 'User', inverse_of: :books

  def publish(advertisements:, free_issue: false)
    result = advertisements * (free_issue ? 2 : 1)
    result = yield(result) if block_given?
    result
  end
end
