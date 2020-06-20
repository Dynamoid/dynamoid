class User
  include Dynamoid::Document

  table name: :USERS

  field :email
  field :type
  field :created_at, :number

  global_secondary_index name: 'INDEX_FOR_EMAIL', hash_key: :email, projected_attributes: :all
  global_secondary_index name: 'INDEX_FOR_TYPE_CREATED_AT', hash_key: :type, range_key: :created_at, projected_attributes: :all
end

User.where(type: 'Client', 'created_at.gt': (DateTime.now - 1.hour).to_i).first
