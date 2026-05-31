### Transactions in Dynamoid

> [!WARNING]
> Please note that this API is experimental and can be changed in
> future releases.

DynamoDB supports modifying and reading operations but there are some
limitations:
- read and write operation cannot be combined in the same transaction
- operations are executed in batch, so operations should be given before
  actual execution and cannot be changed on the fly

#### Modifying transactions

Multiple modifying actions can be grouped together and submitted as an
all-or-nothing operation. Atomic modifying operations are supported in
Dynamoid using transactions. If any action in the transaction fails they
all fail.

The following actions are supported:

* `#create`/`#create!` - add a new model if it does not already exist
* `#save`/`#save!` - create or update a model
* `#update_attributes`/`#update_attributes!` - modify one or more attributes of an existing model
* `#delete` - remove a model without running callbacks or validation
* `#destroy`/`#destroy!` - remove a model
* `#upsert` - add a new model or update an existing one, no callbacks
* `#update_fields` - update a model without its instantiation

These methods are supposed to behave exactly like their
non-transactional counterparts.

Alternatively to `Dynamoid::Document.transaction` (which defaults to a
write transaction) you can use explicit `.writing` method:

```ruby
Dynamoid::Document.transaction.writing do |txn|
  # ...
end
```

##### Create models

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

User.transaction do |t|
  t.create(User, id: user_id)
  t.create(UserEmail, id: "UserEmail##{email}", user_id: user_id)
  t.create(Address, id: 'A#2', street: '456')
  t.upsert(Address, 'A#1', street: '123')
end
```

##### Save models

Models can be saved in a transaction. New records are created otherwise
the model is updated. Save, create, update, validate and destroy
callbacks are called around the transaction as appropriate. Validation
failures will throw `Dynamoid::Errors::DocumentNotValid`.

```ruby
user = User.find(1)
article = Article.new(body: 'New article text', user_id: user.id)

User.transaction do |t|
  t.save(article)

  user.last_article_id = article.id
  t.save(user)
end
```

##### Update models

A model can be updated by providing a model or primary key, and the fields to update.

```ruby
User.transaction do |t|
  # change name and title for a user
  t.update_attributes(user, name: 'bob', title: 'mister')

  # sets the name and title for a user
  # The user is found by id (that equals 1)
  t.update_fields(User, '1', name: 'bob', title: 'mister')

  # sets the name, increments a count and deletes a field
  t.update_fields(User, '1') do |u|
    u.set(name: 'bob')
    u.add(article_count: 1)
    u.delete(:title)
  end

  # adds to a set of integers and deletes from a set of strings
  t.update_fields(User, '2') do |u|
    u.add(friend_ids: [1, 2])
    u.delete(child_names: ['bebe'])
  end
end
```

##### Destroy or delete models

Models can be used or the model class and key can be specified.
`#destroy` uses callbacks and validations. Use `#delete` to skip
callbacks and validations.

```ruby
article = Article.find('1')
tag = article.tag

Article.transaction do |t|
  t.destroy(article)
  t.delete(tag)

  t.delete(Tag, '2') # delete record with hash key '2' if it exists
  t.delete(Tag, 'key#abcd', 'range#1') # when sort key is required
end
```

##### Validation failures that don't raise

All of the transaction methods can be called without the `!` which
results in `false` instead of a raised exception when validation fails.
Ignoring validation failures can lead to confusion or bugs so always
check return status when not using a method with `!`.

```ruby
user = User.find('1')
user.red = true

User.transaction do |t|
  if t.save(user) # won't raise validation exception
    t.update_fields(UserCount, user.id, count: 5)
  else
    puts 'ALERT: user not valid, skipping'
  end
end
```

##### Incrementally building a transaction

Transactions can also be built without a block.

```ruby
transaction = Dynamoid::Document.transaction

transaction.create(User, id: user_id)
transaction.create(UserEmail, id: "UserEmail##{email}", user_id: user_id)
transaction.upsert(Address, 'A#1', street: '123')

transaction.commit # changes are persisted in this moment
```

#### Reading transactions

Multiple reading actions can be grouped together and submitted as an
all-or-nothing operation. Atomic operations are supported in Dynamoid
using transactions. If any action in the transaction fails they all
fail.

The following actions are supported:

* `#find` - load a single model or multiple models by its primary key

These methods are supposed to behave exactly like their
non-transactional counterparts.

Alternatively to `Dynamoid::Document.transaction` (which defaults to a
write transaction) you can use explicit `.reading` method:

```ruby
Dynamoid::Document.transaction.reading do |t|
  # ...
end
```

##### Find a model

The `#find` action can load a single model or multiple ones. Different
model classes can be mixed in the same transaction. The result is returned
as a plain list of all the found models. The order is preserved.

```ruby
user, address = User.transaction.reading do |t|
  t.find(User, user_id)
  t.find(Address, address_id)
end
```

Multiple primary keys can be specified at once:

```ruby
users = User.transaction.reading do |t|
  t.find(User, [id1, id2, id3])
end
```
