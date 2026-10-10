# Persistence & Mutations

Dynamoid provides both high-level methods that run validations and callbacks (similar to ActiveRecord) and low-level methods optimized for high-throughput batch operations, atomic updates, and conditional writes.

---

## Creating Records

### Instantiating and Saving

```ruby
# Build and persist
user = User.new(name: 'Josh', email: 'josh@example.com')
user.save

# Or create in one step
user = User.create(name: 'Josh', email: 'josh@example.com')

# Automatically assigned string UUID if id is not specified
user.id # => "3a9f7216-4726-4aea-9fbc-8554ae9292cb"
```

The bang methods (`save!` and `create!`) raise `Dynamoid::Errors::DocumentNotValid` if validations fail.

### Batch Creation

You can create multiple records at once:

```ruby
# Runs validations and callbacks for each record
users = User.create([{ name: 'Josh' }, { name: 'Nick' }])
```

### High-Performance Bulk Import

When importing large datasets, use `.import`. It uses DynamoDB's `BatchWriteItem` API under the hood, bypassing validations and callbacks for maximum throughput:

```ruby
users = User.import(
  [
    { name: 'Alice', email: 'alice@example.com' },
    { name: 'Bob', email: 'bob@example.com' }
  ]
)
```

---

## Updating Records

### High-Level Updates (With Validations & Callbacks)

These methods validate models and trigger `before_update`, `after_update`, and `save` callbacks:

```ruby
# On an instance
user = User.find(id)
user.update(name: 'Alexander', age: 31)

# On a class
User.update(id, name: 'Alexander')

# Update a single attribute without full validation
user.update_attribute(:active, false)
```

### Low-Level Attribute Updates (`update_fields`)

To update specific attributes directly in DynamoDB without loading the entire document or running validations and callbacks:

```ruby
User.update_fields(id, active: false, login_count: 5)

# Conditional update
User.update_fields(id, { active: false }, if: { status: 'pending' })
```

### Upsert (Create or Update)

`upsert` updates an item if it already exists, or creates a new document if one does not exist:

```ruby
Address.upsert(id, city: 'Chicago', zip: '60601')
Address.upsert(id, { city: 'Chicago' }, if: { deliverable: true })
```

To create an item only if it does not already exist (idempotent creation), use the `unless_exists` condition:

```ruby
Address.upsert(id, { city: 'Chicago' }, { unless_exists: [:id] })
```

### Atomic Counter Increments

To safely increment or decrement a numeric field without race conditions:

```ruby
# Increments view_count by 1
article.inc(:view_count)

# Increments view_count by 5
article.inc(:view_count, 5)
```

### Update Expressions (Set, Add, Delete)

For granular control over DynamoDB update operations, pass a block to `#update`:

```ruby
user = User.find(id)
user.update do |u|
  u.set city: 'Chicago'
  u.add score: 10
  u.delete tags: ['old_tag'] # Removes elements from a Set
end
```

You can also attach conditions to update expressions:

```ruby
user.update(if: { active: true }) do |u|
  u.set role: 'admin'
end
```

---

## Optimistic Locking (Concurrency Control)

Dynamoid supports ActiveRecord-style optimistic locking to prevent concurrent overwrite issues. To enable optimistic locking on a table, simply declare an integer `lock_version` field:

```ruby
class Account
  include Dynamoid::Document

  field :balance, :number
  field :lock_version, :integer
end
```

### How It Works:
1. When an item is loaded, Dynamoid records its `lock_version`.
2. When the item is saved, Dynamoid attaches a condition requiring `lock_version` to match the loaded value, while incrementing `lock_version` by 1.
3. If another process modified the item in the meantime, DynamoDB rejects the write, and Dynamoid raises `Dynamoid::Errors::StaleObjectError`.

```ruby
account = Account.find(account_id)

begin
  account.balance += 100
  account.save
rescue Dynamoid::Errors::StaleObjectError
  # Conflict detected: reload and retry
  account.reload
  retry
end
```

---

## Deleting Records

### Instance Deletion

`destroy` deletes the item from DynamoDB and runs `before_destroy` / `after_destroy` callbacks:

```ruby
user = User.find(id)
user.destroy
user.destroyed? # => true
```

### Unloaded Batch Deletion (`delete_all`)

To delete matching records efficiently using DynamoDB's `BatchWriteItem` without loading full objects or executing callbacks:

```ruby
# Delete matching items
User.where(active: false).delete_all

# Delete directly by primary key
User.delete(user_id)
```
