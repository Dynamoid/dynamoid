# Transactions in Dynamoid

Synchronous write operations are supported in Dynamoid using transactions.
If any action in the transaction fails they all fail.
The following actions are supported:

* Create - add a new item if it does not already exist
* Upsert - add a new item or update an existing item, no callbacks
* Update - modifies one or more attributes from an existig item
* Delete - remove an item without callbacks, validations nor existence check
* Destroy - remove an item, fails if item does not exist

## Examples



### Save models
Models can be saved in a transaction.
New records are created otherwise the model is updated.
Save, create, update, validate and destroy callbacks are called around the transaction as appropriate.
Validation failures will throw Dynamoid::Errors::DocumentNotValid.

```ruby
user = User.find(1)
article = Article.new(body: 'New article text', user_id: user.id)
Dynamoid::TransactionWrite.execute do |txn|
  txn.save!(article)
  user.last_article_id = article.id
  txn.save!(user)
end
```

### Create items
Items can be created inside of a transaction.
The hash key and range key, if applicable, are used to determine uniqueness.
Creating will fail with Aws::DynamoDB::Errors::TransactionCanceledException if an item already exists.
This example creates a user with a  unique id and unique email address by creating 2 items.
An additional item is upserted in the same transaction.
Upserts will update updated_at but will not create created_at.

```ruby
user_id = SecureRandom.uuid
email = 'bob@bob.bob'
Dynamoid::TransactionWrite.execute do |txn|
  txn.create!(User, id: user_id)
  txn.create!(UserEmail, id: "UserEmail##{email}", user_id: user_id)
  txn.create!(Address, { id: 'A#2', street: '456' })
  txn.upsert!(Address, id: 'A#1', street: '123')
end
```

### Update items
An item can be updated by providing the hash key, range key if applicable, and the fields to update.
Updating fields can also be done within a block using the `set()` method.
To increment a numeric value or to add values to a set use `add()` within the block.
Similarly a field can be removed or values can be removed from a set by using `delete()` in the block.
```ruby
Dynamoid::TransactionWrite.execute do |txn|
  # sets the name and title for user 1
  # The user is found by id
  txn.update!(User, id: 1, name: 'bob', title: 'mister')

  # sets the name, increments a count and deletes a field
  txn.update!(user) do |u| # a User instance is provided
    u.set(name: 'bob')
    u.add(article_count: 1)
    u.delete(:title)
  end

  # adds to a set of integers and deletes from a set of strings
  txn.update!(User, id: 3) do |u|
    u.add(friend_ids: [1, 2])
    u.delete(child_names: ['bebe'])
  end
end
```

### Destroy or delete items
Models can be used or the model class and key can be specified.
When the key is a single column it is specified as a single value or a hash
with the name of the hash key.
When using a composite key the key must be a hash with the hash key and range key.
destroy() uses callbacks and validations and fails if the item does not exist.
Use delete() to skip callbacks, validations and the existence check.

```ruby
article = Article.find(1)
tag = article.tag
Dynamoid::TransactionWrite.execute do |txn|
  txn.destroy!(article)
  txn.destroy!(Article, 2) # performs find() automatically and then runs destroy callbacks
  txn.destroy!(tag)
  txn.delete(Tag, 2) # delete record with hash key '2' if it exists
  txn.delete(Tag, id: 2) # equivalent of the above if the hash key column is 'id'
  txn.delete(Tag, id: 'key#abcd', my_sort_key: 'range#1') # when range key is required
end
```

### Skipping callbacks and validations
Validations and callbacks can be skipped per action.
Validation failures will throw Dynamoid::Errors::DocumentNotValid when using the bang! methods.
Note that validation callbacks are run when validation happens even if skipping callbacks here.
Skipping callbacks and validation guarantees no callbacks.

```ruby
user = User.find(1)
user.red = true
Dynamoid::TransactionWrite.execute do |txn|
  txn.save!(user, skip_callbacks: true)
  txn.create!(User, { name: 'bob' }, { skip_callbacks: true })
end
Dynamoid::TransactionWrite.execute do |txn|
  txn.save!(user, skip_validation: true)
  txn.create!(User, { name: 'bob' }, { skip_validation: true })
end
```

### Validation failures that don't raise
All of the transaction methods can be called without the bang! which results in
false instead of a raised exception when validation fails.
Ignoring validation failures can lead to confusion or bugs so always check return status when not using a bang!

```ruby
user = User.find(1)
user.red = true
Dynamoid::TransactionWrite.execute do |txn|
  if txn.save(user) # won't raise validation exception
    txn.update(UserCount, id: 'UserCount#Red', count: 5)
  else
    puts 'ALERT: user not valid, skipping'
  end
end
```

### Incrementally building a transaction
Transactions can also be built without a block.

```ruby
transaction = Dynamoid::TransactionWrite.new
transaction.create!(User, id: user_id)
transaction.create!(UserEmail, id: "UserEmail##{email}", user_id: user_id)
transaction.upsert!(Address, id: 'A#1', street: '123')
transaction.commit
```
