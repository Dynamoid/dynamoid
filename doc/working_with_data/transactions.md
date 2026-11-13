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

Dynamoid models its transactional interface after familiar persistence methods. Start a write transaction on any model class with `transaction` (or `transaction.writing`), and invoke persistence methods on the transaction object yielded to the block rather than on a model or class directly.

Transactional counterparts to model instance methods (such as `save!`, `update_attributes!`, and `destroy`) are called as follows:

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

Similarly, transactional counterparts to class methods (such as `create!`, `update_fields`, `upsert`, and `delete`) are called as follows:

```ruby
User.transaction do |t|
  t.create!(User, name: 'Bob')
  t.update_fields(Account, account_id, balance: 500)
  t.delete(Account, old_account_id)
end
```

> [!NOTE]
> Operations performed inside a write transaction are queued and not persisted to DynamoDB until the block commits. Reading from DynamoDB inside the block—or inside callbacks such as `after_save` and `after_create`—returns the pre-transaction state. To run logic after changes are persisted in DynamoDB, use `after_commit` callbacks (see [Commit and Rollback](callbacks.md#commit-and-rollback)).

Validation and callbacks run immediately when a persistence method is called inside the block. With bang methods (such as `save!`, `create!`, and `update_attributes!`), a validation failure raises an exception, terminating the block and cancelling the entire transaction:

```ruby
User.transaction do |t|
  t.save!(user)
end
```

To handle invalid models without raising an exception, check `valid?` or use non-bang methods (such as `save`, `create`, and `update_attributes`), which skip the invalid model and allow the remaining operations in the transaction to proceed:

```ruby
User.transaction do |t|
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

When DynamoDB rejects a transaction—due to a concurrent write conflict, an optimistic locking mismatch, or a duplicate primary key—it cancels the entire batch and raises a single exception instead of `RecordNotUnique` or `StaleObjectError`:

```ruby
begin
  User.transaction do |t|
    t.create!(User, id: user_id, name: 'Alice')
    t.update_fields(Account, account_id, balance: 100)
  end
rescue Aws::DynamoDB::Errors::TransactionCanceledException
  # Handle conflict, duplicate key, or retry
end
```

When you cannot wrap all operations in a single block—for example, when accumulating changes across separate methods or objects—you can build a write transaction incrementally and commit it explicitly:

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

Similarly, you can build a read transaction incrementally without a block:

```ruby
t = Dynamoid::Transactions::Retrieval.new

t.find(User, user_id)
t.find(Account, account_id)

user, account = t.commit
```

{{#include ../_includes/feedback.md}}
