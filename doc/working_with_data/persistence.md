# Persistence

Dynamoid provides a persistence interface modeled closely after Rails Active Record. Standard methods like `new`, `save`, `create`, `update_attributes`, `delete`, and `destroy` provide familiar lifecycle behavior—triggering validations and callbacks, tracking dirty attributes, and enforcing optimistic locking.

Beyond the standard in-memory lifecycle, Dynamoid provides a database-level interface that modifies items directly in DynamoDB without loading them first. This allows you to perform partial updates and upserts in a single request, execute atomic mutations (such as counter increments and set changes) without race conditions, and guard writes with condition expressions.

Code examples throughout this guide refer to this model:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :age, :integer
  field :tags, :set, of: :string
end
```

> [!NOTE]
> For models with a composite primary key, class-level persistence methods (`update`, `delete`, `update_fields`, `upsert`, `inc`) accept the sort key as the second argument (for example, `Model.delete(partition_key, sort_key)`).

## Core Operations

Dynamoid provides standard persistence methods for creating, updating, and deleting model instances in DynamoDB:

### Creating Models

To initialize a model in memory without writing to DynamoDB, call `new` and then persist it with `save`:

```ruby
user = User.new(name: 'Alice', age: 30)
user.new_record? # => true
user.persisted?  # => false

user.save # => true
user.new_record? # => false
user.persisted?  # => true
```

DynamoDB does not auto-generate primary keys. For a model with a string partition key (`id` by default), Dynamoid assigns a random UUID automatically if a value is not provided explicitly:

```ruby
user.id # => "3a9f7216-4726-4aea-9fbc-8554ae9292cb"
```

To instantiate and persist a model in a single call, use `create`:

```ruby
user = User.create(name: 'Alice', age: 30)
```

Both `new` and `create` also accept a block to initialize attributes on the model instance:

```ruby
user = User.create do |u|
  u.name = 'Alice'
  u.age = 30
end
```

You can also pass an array of attribute hashes to `create` to persist multiple models sequentially, running validations and callbacks for each model:

```ruby
users = User.create(
  [
    { name: 'Alice', age: 30 },
    { name: 'Bob', age: 25 }
  ]
)
```

When inserting multiple items where validations and callbacks are not needed, use `import` to write items in batches instead of issuing a separate request per model:

```ruby
users = User.import(
  [
    { name: 'Alice', age: 30 },
    { name: 'Bob', age: 25 }
  ]
)
```

> [!WARNING]
> Because Dynamoid only generates UUIDs for string partition keys, any non-string partition key must be populated explicitly.

### Updating Models

To update an existing item, load the model, modify its attributes in memory, and call `save`:

```ruby
user = User.find(user_id)
user.name = 'Alicia'
user.save
```

To update multiple attributes and save the model in a single call, use `update_attributes`:

```ruby
user.update_attributes(name: 'Alicia', age: 31)
```

To update an item by its primary key without calling `find` first, use `Model.update`:

```ruby
user = User.update(user_id, name: 'Alicia', age: 31)
```

To reload attributes from DynamoDB using a consistent read, call `reload`:

```ruby
user.reload
```

To update the `updated_at` timestamp directly in DynamoDB without writing unchanged attributes, call `touch`:

```ruby
user.touch
```

> [!WARNING]
> DynamoDB does not allow modifying an item's partition key or sort key once persisted. To change a key value, you must create a new item with the new key and delete the original item.

### Deleting Models

To remove a loaded model from DynamoDB and run `destroy` callbacks, call `destroy`:

```ruby
user = User.find(user_id)
user.destroy
user.destroyed? # => true
user.persisted? # => false
```

To remove a loaded model immediately without running callbacks, call `delete`:

```ruby
user.delete
user.destroyed? # => true
```

To delete one or more items directly by partition key without loading them into memory first, call `Model.delete` with a single key or an array of keys:

```ruby
User.delete(user_id)
User.delete([user_id_1, user_id_2, user_id_3])
```

## Database-Level and Atomic Updates

Instead of loading an item into memory and saving it back, you can modify items directly in DynamoDB with a single request. This avoids unnecessary read requests and prevents race conditions when updating attributes, incrementing counters, or mutating sets:

`Model.update_fields` modifies specific attributes on an existing item directly in DynamoDB without loading it into memory:

```ruby
user = User.update_fields(user_id, name: 'Alicia', age: 31)
# => #<User id: "...", name: "Alicia", age: 31> (or nil if not found)
```

When an item may or may not already exist, `Model.upsert` updates the item by primary key or creates a new one if it is missing:

```ruby
user = User.upsert(user_id, name: 'Alice', age: 30)
# => #<User id: "...", name: "Alice", age: 30>
```

For numeric counters, `Model.inc` atomically adjusts values in DynamoDB in a single request (pass a negative number to decrement):

```ruby
User.inc(user_id, age: 1)
User.inc(user_id, age: -1)
```

On a loaded model instance, `#update` and `#update!` accept a block combining low-level DynamoDB mutation actions (`set` to assign values, `add` to increment numbers or append to sets, and `delete` to remove set elements or scalar attributes) in a single atomic request:

```ruby
user.update! do |t|
  t.set(name: 'Alicia')
  t.add(age: 1, tags: %w[admin verified])
  t.delete(tags: ['guest']) # Removes elements from a set
  t.delete(:age)            # Removes the attribute completely from the item
end
```

These update methods also support conditional updates using `if:` or `unless_exists:`:

```ruby
# Returns nil if the condition is not met
User.update_fields(user_id, { age: 31 }, if: { age: 30 })
# => nil (when age != 30)

# Idempotent insert: create only if the primary key does not exist yet
User.upsert(user_id, { name: 'Alice' }, unless_exists: [:id])
# => nil (when :id exists)

# Returns false if the condition is not met
user.update(if: { name: 'Alice' }) do |t|
  t.set(name: 'Alicia')
  t.add(age: 1)
end
# => false (when name != "Alice")

# Or raises an exception with update!
user.update!(if: { name: 'Alice' }) do |t|
  t.set(name: 'Alicia')
end
# Raises Dynamoid::Errors::StaleObjectError (when name != "Alice")
```

## Validations

Dynamoid allows you to validate the state of a model before it is written to DynamoDB using standard Rails validators—such as `presence`, `numericality`, `inclusion`, `length`, and `format`—as well as custom validation methods:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :age, :integer

  validates :name, presence: true
  validates :age, numericality: { greater_than_or_equal_to: 18 }
end
```

When a model is invalid, `save` and `update_attributes` return `false` without writing to DynamoDB, and `create` returns the unsaved model instance:

```ruby
user = User.new(age: 15)
user.valid?               # => false
user.errors[:name]        # => ["can't be blank"]
user.errors.full_messages # => ["Name can't be blank", "Age must be greater than or equal to 18"]
user.save                 # => false
```

If you want an invalid model to raise an exception instead, use the bang counterparts (`save!`, `create!`, `update_attributes!`, and `Model.update!`):

```ruby
user.save! # Raises Dynamoid::Errors::DocumentNotValid
```

To bypass validations when saving a model, pass `validate: false`:

```ruby
user.save(validate: false) # => true
```

> [!NOTE]
> Dynamoid does not support uniqueness validations (such as `validates_uniqueness_of`) because DynamoDB cannot enforce uniqueness on non-key attributes without scanning the entire table. Enforce uniqueness using dedicated lookup tables or DynamoDB transactions instead.

## Dirty Attribute Tracking

Dynamoid tracks unsaved in-memory attribute changes on every model instance. Modifying an attribute marks it as dirty until the model is saved or reloaded, which lets you inspect pending modifications and allows `save` to send only modified attributes to DynamoDB:

```ruby
user = User.find(user_id) # user.name is "Alice"
user.changed?      # => false
user.name_changed? # => false

user.name = 'Alicia'
user.changed?      # => true
user.name_changed? # => true
user.name_was      # => "Alice"
user.changes       # => { "name" => ["Alice", "Alicia"] }
```

In-place mutations on mutable Ruby objects—such as mutating strings with `!` methods, adding or removing elements in a `Set` or `Array`, or updating keys inside a `Hash`—are also detected automatically without reassigning the attribute:

```ruby
user = User.create(name: 'Alice', tags: ['ruby'])

user.name.upcase!
user.tags << 'dynamodb'

user.name_changed? # => true
user.tags_changed? # => true

user.save # Persists the mutated string and set
```

To explicitly flag an attribute as dirty before modifying it, call `<attribute>_will_change!`:

```ruby
user.name_will_change!
```

When `save` completes, the model's unsaved changes are cleared, and the recorded modifications become accessible through `previous_changes` and `<attribute>_previously_changed?` (useful inside `after_save` or `after_update` callbacks):

```ruby
user.name = 'Alicia'
user.save

user.changed?                 # => false
user.name_previously_changed? # => true
user.previous_changes         # => { "name" => ["Alice", "Alicia"], "updated_at" => [...] }
```

To discard unsaved in-memory modifications and restore attributes to their persisted values without querying DynamoDB, call `restore_attributes` (or `restore_<attribute>!` for an individual attribute):

```ruby
user.name = 'Temporary'
user.restore_attributes
user.name # => "Alicia"
```

> [!NOTE]
> For custom field types, Dynamoid detects in-place mutations by comparing serialized values or by using `#==` when `comparable: true` is configured (see [Change Detection](../modeling_and_schema/fields_and_data_types.md#change-detection)).

## Optimistic Locking

When multiple processes load the same item, modify it in memory, and save it back, the later save can silently overwrite changes made by the earlier process. Dynamoid supports optimistic locking to detect concurrent modifications and prevent lost updates.

To enable optimistic locking on a model, declare an integer field named `lock_version`:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :lock_version, :integer
end
```

When a new model is saved, Dynamoid initializes `lock_version` to `1`. On every subsequent `save`, it increments `lock_version` by `1` and verifies that the item has not changed in DynamoDB since it was loaded. If another process modified or deleted the item in the meantime, the save fails and Dynamoid raises an exception:

```ruby
user_a = User.find(user_id)
user_b = User.find(user_id)

user_a.name = 'Alice'
user_a.save! # Succeeds; lock_version increments from 1 to 2

user_b.name = 'Alicia'
user_b.save! # Raises Dynamoid::Errors::StaleObjectError
```

To recover from a conflict, rescue `Dynamoid::Errors::StaleObjectError`, reload the model to fetch the latest attributes and `lock_version`, re-apply your changes, and retry:

```ruby
begin
  user.age += 1
  user.save!
rescue Dynamoid::Errors::StaleObjectError
  user.reload
  retry
end
```

To disable optimistic locking for a specific item, set its `lock_version` to `nil`:

```ruby
user.update_attributes(lock_version: nil)
```

{{#include ../_includes/feedback.md}}
