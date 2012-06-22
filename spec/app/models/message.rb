class Message
  include Dynamoid::Document

  table name: :messages, key: :message_id, read_capacity: 200, write_capacity: 200

  range :time, :datetime

  field :text
end
