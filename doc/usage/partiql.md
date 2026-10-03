# PartiQL

Amazon DynamoDB supports [PartiQL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ql-reference.html), a SQL-compatible query language that allows you to select, insert, update, and delete data in DynamoDB tables using familiar SQL syntax.

In Dynamoid, you can execute raw PartiQL queries directly through the adapter using `Dynamoid.adapter.execute`.

---

## Executing Queries

### 1. Selecting Data

You can execute `SELECT` queries with positional parameter binding:

```ruby
# Query with positional parameter
results = Dynamoid.adapter.execute('SELECT * FROM users WHERE id = ?', ['user-123'])

results.each do |item|
  puts item['name']
end
```

### 2. Inserting Data

```ruby
Dynamoid.adapter.execute(
  'INSERT INTO users VALUE { ? : ?, ? : ?, ? : ? }',
  ['id', 'user-456', 'name', 'Alex', 'active', true]
)
```

### 3. Updating Data

```ruby
Dynamoid.adapter.execute(
  'UPDATE users SET name = ? WHERE id = ?',
  %w[Alexander user-123]
)
```

### 4. Deleting Data

```ruby
Dynamoid.adapter.execute('DELETE FROM users WHERE id = ?', ['user-123'])
```

---

## Important Considerations

* **Table Names:** In PartiQL statements, table names must match the exact DynamoDB table name (including the namespace prefix, e.g. `User.table_name`).
* **Returned Data:** Unlike `User.where(...)`, raw PartiQL queries via `Dynamoid.adapter.execute` return plain Ruby hashes representing DynamoDB items rather than fully instantiated `Dynamoid::Document` model instances.
