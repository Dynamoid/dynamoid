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
An item can be updated by providing a model or hash key and range key if applicable, and the fields to update.
```ruby
Dynamoid::TransactionWrite.execute do |txn|
  # change name and title for a user
  txn.update_attributes!(user, name: 'bob', title: 'mister')

  # sets the name and title for a user
  # The user is found by id (that equals 1)
  txn.update_fields!(User, 1, name: 'bob', title: 'mister')
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
