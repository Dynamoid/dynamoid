# Associations

Dynamoid supports familiar ActiveRecord-style associations to define relationships between models: `belongs_to`, `has_one`, `has_many`, and `has_and_belongs_to_many`.

```ruby
class User
  include Dynamoid::Document

  field :name, :string

  has_many :addresses
  has_one :profile
  has_and_belongs_to_many :teams
end

class Address
  include Dynamoid::Document

  field :city, :string

  belongs_to :user
end
```

> **Warning (Composite Keys Limitation):** Associations are only supported for models with a **simple primary key** (partition key only). If a model defines a sort key (`range`), it cannot declare associations or be the target of an association from another model.

---

## Supported Associations

### 1. `belongs_to` and `has_one` (One-to-One)

```ruby
class User
  include Dynamoid::Document

  has_one :profile
end

class Profile
  include Dynamoid::Document

  belongs_to :user
end
```

### 2. `has_many` (One-to-Many)

```ruby
class Author
  include Dynamoid::Document

  has_many :books
end

class Book
  include Dynamoid::Document

  belongs_to :author
end
```

### 3. `has_and_belongs_to_many` (Many-to-Many)

Unlike relational databases that require a join table, Dynamoid stores many-to-many associations directly within each document as a Set of foreign IDs.

```ruby
class Student
  include Dynamoid::Document

  has_and_belongs_to_many :courses
end

class Course
  include Dynamoid::Document

  has_and_belongs_to_many :students
end
```

---

## Association Options

You can customize association resolution with standard options:

* `:class` or `:class_name` - Explicitly specify the associated model class:
  ```ruby
belongs_to :manager, class_name: 'User'
has_many :subordinates, class: User
  ```
* `:foreign_key` - Specify a custom attribute name for the reference:
  ```ruby
belongs_to :organization, foreign_key: :org_id
  ```
* `:inverse_of` - Specify the reciprocal association on the target model:
  ```ruby
has_and_belongs_to_many :friends, inverse_of: :friending_users
  ```

---

## Working with Associations

### Creating Associated Records

```ruby
user = User.create(name: 'Josh')

# Create and automatically associate
address = user.addresses.create(city: 'Chicago')

# Re-read associated records
user.addresses.all # => [#<Address id: "...", city: "Chicago">]
```

### Querying on Associations

You can query across an association collection using `.where(...)`:

```ruby
user.addresses.where(city: 'Chicago').all
```

### DynamoDB Performance Considerations

In a relational database, associations are resolved using SQL `JOIN` statements. DynamoDB does not have joins:
* To load `user.addresses`, Dynamoid reads the stored collection of address IDs from the `user` item, then executes a `BatchGetItem` request to retrieve the corresponding `addresses` items from DynamoDB.
* When querying associations with `.where(...)`, Dynamoid loads the associated items and filters them in Ruby memory. For large collections, keep this latency and read capacity trade-off in mind.
