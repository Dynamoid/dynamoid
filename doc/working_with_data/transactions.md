# Transactions

DynamoDB transactions provide atomicity, consistency, isolation, and durability (ACID) across one or more items and tables. When you execute a transaction, DynamoDB coordinates all included actions as a single atomic unit—either every operation succeeds and persists, or the entire transaction is cancelled with no partial modifications applied. Operations execute with serializable isolation.

## Limitations

DynamoDB transactions are non-interactive batch operations. Instead of running queries interactively and branching based on intermediate results, you define all actions upfront, and DynamoDB executes the entire batch together as an all-or-nothing request. When writing transactional code in Dynamoid, keep the following constraints in mind:

* *No interactive read-and-write* — operations are executed in a single batch rather than step-by-step.
* *Separation of reads and writes* — read operations and write operations cannot be combined in the same transaction.
* *Item limit* — a single transaction can contain at most 100 items.
* *Unique item targets* — a write transaction cannot perform multiple actions on the same item.

For details on best practices, conflict resolution, and capacity planning, see the [Amazon DynamoDB Transactions Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html).

## Writing Transactions

Dynamoid models its transactional interface after familiar persistence methods. Rather than calling methods on a model or class directly, you invoke them on the transaction object yielded to the block.

You can start a write transaction on any model class with `.transaction` (which defaults to write operations) or explicitly with `.transaction.writing`.

For operations that modify or delete an in-memory model instance—such as `save!`, `update_attributes!`, and `destroy`—pass the model instance as the argument:

```ruby
user = User.new(name: 'Alice')
account = Account.find(account_id)
old_account = Account.find(old_account_id)

User.transaction do |t|
  t.save!(user)
  t.update_attributes!(account, balance: 250)
  t.destroy(old_account)
end
```

For operations that create models or modify items directly in DynamoDB without loading them first—such as `create!`, `update_fields`, `upsert`, and `delete`—pass the model class as the first argument, followed by the primary key or attributes:

```ruby
User.transaction do |t|
  t.create!(User, name: 'Bob')
  t.update_fields(Account, account_id, balance: 500)
  t.delete(Account, old_account_id)
end
```

Operations performed inside a write transaction are not persisted to DynamoDB until the entire block commits. As a result, you cannot read these changes from DynamoDB while the transaction is still running—neither from subsequent code in the block nor from callbacks like `after_save` and `after_create`. Any read from DynamoDB will return stale data (or find nothing if the item is new). To run logic that depends on data actually existing in DynamoDB, use `after_commit` callbacks (see the [Callbacks guide](callbacks.md)).

For bang methods (such as `save!`, `create!`, and `update_attributes!`), validation runs immediately when called. If validation fails, an exception is raised, terminating the block and cancelling the entire transaction:

```ruby
User.transaction do |t|
  t.save!(user) # Raises Dynamoid::Errors::DocumentNotValid if invalid

  account = Account.new(user_id: user.id, balance: 100)
  if account.valid?
    t.save(account)
  end
end
```

Any unhandled exception raised inside the block cancels the transaction and re-raises the error. To abort a transaction deliberately without propagating an exception, raise `Dynamoid::Errors::Rollback`. Dynamoid rescues this exception, cancels all queued writes, runs `after_rollback` callbacks, and exits the block cleanly:

```ruby
User.transaction do |t|
  t.save!(user)
  t.update_fields(Account, account_id, balance: 250)

  raise Dynamoid::Errors::Rollback if user.suspended?
end
```

When DynamoDB rejects a transaction—due to a concurrent write conflict, an optimistic locking mismatch (`lock_version`), or an already existing ID—it cancels the entire batch and raises `Aws::DynamoDB::Errors::TransactionCanceledException`. Unlike non-transactional operations, transactional methods do not raise `RecordNotUnique` or `StaleObjectError`. You can rescue this exception to handle conflicts or retry:

```ruby
begin
  User.transaction do |t|
    t.create!(User, id: user_id, name: 'Alice')
    t.update_fields(Account, account_id, balance: 100)
  end
rescue Aws::DynamoDB::Errors::TransactionCanceledException => e
  # Handle conflict, duplicate key, or retry
end
```

You can also construct a transaction incrementally across multiple methods or workflow steps without a block. Instantiate `Dynamoid::Transactions::Mutation.new`, register operations, and call `#commit` to persist all changes (or `#rollback` to discard them):

```ruby
t = Dynamoid::Transactions::Mutation.new

t.create!(User, name: 'Alice')
t.update_fields(Account, account_id, balance: 250)

t.commit
```

## Reading Transactions

Reading transactions retrieve items across one or more tables in a single consistent snapshot. You start a read transaction by calling `.transaction.reading` on any model class.

Because DynamoDB executes transactional reads in a single batch, calling `find` inside the block does not load data immediately. Instead, Dynamoid queues each read and fetches all items together when the block exits. You cannot inspect loaded models inside the block itself; once the block completes, it returns an array containing all requested models:

```ruby
user, account = User.transaction.reading do |t|
  t.find(User, user_id)
  t.find(Account, account_id)
end
```

When calling `find` with arrays of IDs, the transaction returns a single flattened array containing all loaded models in the order requested:

```ruby
results = User.transaction.reading do |t|
  t.find(User, [user_id_1, user_id_2])
  t.find(Account, [account_id_1, account_id_2])
end
# => [user_1, user_2, account_1, account_2]
```

You can also construct a read transaction incrementally without a block using `Dynamoid::Transactions::Retrieval.new`:

```ruby
t = Dynamoid::Transactions::Retrieval.new

t.find(User, user_id)
t.find(Account, account_id)

user, account = t.commit
```

{{#include ../_includes/feedback.md}}
