# Associations

Just like in ActiveRecord (or your other favorite ORM), Dynamoid uses
associations to create links between models.

**WARNING:** Associations are not supported for models with a compound
primary key. If a model declares a range key it should not declare any
association itself and be referenced by an association in another model.

The only supported associations (so far) are `has_many`, `has_one`,
`has_and_belongs_to_many`, and `belongs_to`. Associations are very
simple to create: just specify the type, the name, and then any options
you'd like to pass to the association. If there's an inverse association
either inferred or specified directly, Dynamoid will update both objects
to point at each other.

```ruby
class User
  include Dynamoid::Document

  # ...

  has_many :addresses
  has_many :students, class: User
  belongs_to :teacher, class_name: :user
  belongs_to :group
  belongs_to :group, foreign_key: :group_id
  has_one :role
  has_and_belongs_to_many :friends, inverse_of: :friending_users
end

class Address
  include Dynamoid::Document

  # ...

  belongs_to :user # Automatically links up with the user model
end
```

Contrary to expectations, association information is always
contained on the object specifying the association, even if it seems
like the association has a foreign key. This is a side effect of
DynamoDB's structure: it's very difficult to find foreign keys without
an index. Usually you won't find this to be a problem, but it does mean
that association methods that build new models will not work correctly -
for example, `user.addresses.new` returns an address that is not
associated with the user. We'll be correcting this in a future version.
