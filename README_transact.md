# Transactions in Dynamoid

Multiple modifying actions can be grouped together and submitted as an
all-or-nothing operation. Atomic modifying operations are supported in
Dynamoid using transactions. If any action in the transaction fails they
all fail.

The following actions are supported:

* `#create` - add a new model if it does not already exist
* `#save` - create or update model
* `#update_attributes` - modifies one or more attributes from an existig
  model
* `#delete` - remove an model without callbacks nor validations
* `#destroy` - remove an model
* `#upsert` - add a new model or update an existing one, no callbacks
* `#update_fields` - update a model without its instantiation

These methods are supposed to behave exactly like their
non-transactional counterparts.

## Examples

### Create models

Models can be created inside of a transaction. The partition and sort
keys, if applicable, are used to determine uniqueness. Creating will
fail with `Aws::DynamoDB::Errors::TransactionCanceledException` if a
model already exists.

This example creates a user with a unique id and unique email address by
creating 2 models. An additional model is upserted in the same
transaction. Upsert will update `updated_at` but will not create
`created_at`.

```ruby
user_id = SecureRandom.uuid
email = 'bob@bob.bob'

Dynamoid::TransactionWrite.execute do |txn|
  txn.create(User, id: user_id)
  txn.create(UserEmail, id: "UserEmail##{email}", user_id: user_id)
  txn.create(Address, id: 'A#2', street: '456')
  txn.upsert(Address, id: 'A#1', street: '123')
end
```

### Save models

Models can be saved in a transaction. New records are created otherwise
the model is updated. Save, create, update, validate and destroy
callbacks are called around the transaction as appropriate. Validation
failures will throw `Dynamoid::Errors::DocumentNotValid`.

```ruby
user = User.find(1)
article = Article.new(body: 'New article text', user_id: user.id)

Dynamoid::TransactionWrite.execute do |txn|
  txn.save(article)

  user.last_article_id = article.id
  txn.save(user)
end
```

### Update models

A model can be updated by providing a model or primary key, and the fields to update.

```ruby
Dynamoid::TransactionWrite.execute do |txn|
  # change name and title for a user
  txn.update_attributes(user, name: 'bob', title: 'mister')

  # sets the name and title for a user
  # The user is found by id (that equals 1)
  txn.update_fields(User, '1', name: 'bob', title: 'mister')
end
```

### Destroy or delete models

Models can be used or the model class and key can be specified.
`#destroy` uses callbacks and validations. Use `#delete` to skip
callbacks and validations.

```ruby
article = Article.find('1')
tag = article.tag

Dynamoid::TransactionWrite.execute do |txn|
  txn.destroy(article)
  txn.delete(tag)

  txn.delete(Tag, '2') # delete record with hash key '2' if it exists
  txn.delete(Tag, 'key#abcd', 'range#1') # when sort key is required
end
```

## Validation failures that don't raise

All of the transaction methods can be called without the `!` which
results in `false` instead of a raised exception when validation fails.
Ignoring validation failures can lead to confusion or bugs so always
check return status when not using a method with `!`.

```ruby
user = User.find('1')
user.red = true

Dynamoid::TransactionWrite.execute do |txn|
  if txn.save(user) # won't raise validation exception
    txn.update(UserCount, id: 'UserCount#Red', count: 5)
  else
    puts 'ALERT: user not valid, skipping'
  end
end
```

## Incrementally building a transaction

Transactions can also be built without a block.

```ruby
transaction = Dynamoid::TransactionWrite.new

transaction.create(User, id: user_id)
transaction.create(UserEmail, id: "UserEmail##{email}", user_id: user_id)
transaction.upsert(Address, id: 'A#1', street: '123')

transaction.commit # changes are persisted in this moment
```
