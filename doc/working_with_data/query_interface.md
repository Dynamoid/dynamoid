# Query Interface

## 1. What is the Query Interface?

If you are accustomed to querying DynamoDB with the AWS SDK, retrieving data typically requires constructing low-level parameter hashes for operations like `GetItem`, `BatchGetItem`, `Query`, and `Scan`. Dynamoid provides an expressive, chainable query interface modeled after Active Record, abstracting low-level SDK calls while adapting to DynamoDB's partitioning and indexing model.

Query methods like `where` return a criteria chain. Similar to an Active Record relation, a criteria chain evaluates lazily. Dynamoid does not execute network requests against DynamoDB until you iterate over results, access an item, or call an execution method such as `all`, `first`, `each`, or `count`.

```ruby
# Builds a criteria chain without executing a request
query = User.where(active: true)

# Executes a request against DynamoDB when iterating or evaluating
query.each do |user|
  puts user.name
end
```

### Example Models

Throughout this guide, code examples refer to the following models:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :active, :boolean
end

class Order
  include Dynamoid::Document

  range :placed_at, :datetime
  field :total, :number
end
```

## 2. Retrieving Items from the Database

Dynamoid provides finder methods to retrieve individual items or collections directly from DynamoDB without constructing low-level queries.

### 2.1 Retrieving a Single Item

Use `find` to look up an item by its partition key. If no matching item exists, Dynamoid raises `Dynamoid::Errors::RecordNotFound`:

```ruby
user = User.find('3a9f7216-4726-4aea-9fbc-8554ae9292cb')
# => #<User id: "3a9f7216...", name: "Alice", active: true>
```

You can also retrieve multiple items at once by passing multiple keys as separate arguments or as an array:

```ruby
users = User.find('3a9f7216-4726-4aea-9fbc-8554ae9292cb', 'b2c89f14-8742-4b8a-9e11-7394851239aa')
# Or pass an array:
# users = User.find(%w[3a9f7216-4726-4aea-9fbc-8554ae9292cb b2c89f14-8742-4b8a-9e11-7394851239aa])
# => [#<User id: "3a9f7216...", name: "Alice", active: true>, #<User id: "b2c89f14...", name: "Bob", active: false>]
```

> [!WARNING]
> Dynamoid raises `Dynamoid::Errors::RecordNotFound` if any of the requested items cannot be found. The order of items in the returned array is not guaranteed to match the order of the supplied IDs.

When a table uses a composite primary key, pass the sort key via the `range_key:` keyword argument. Omitting the sort key raises `Dynamoid::Errors::MissingRangeKey`:

```ruby
order = Order.find('d7e34b12-9214-46c5-8e42-123456789abc', range_key: '2026-03-01T10:00:00Z')
# => #<Order id: "d7e34b12...", placed_at: 2026-03-01 10:00:00 UTC, total: 100>
```

For composite primary keys, retrieve multiple items by passing an array of `[partition_key, sort_key]` pairs:

```ruby
orders = Order.find(
  [
    ['d7e34b12-9214-46c5-8e42-123456789abc', '2026-03-01T10:00:00Z'],
    ['e8f45c23-0325-47d6-9f53-234567890bcd', '2026-03-02T12:00:00Z']
  ]
)
# => [#<Order id: "d7e34b12...", placed_at: 2026-03-01 10:00:00 UTC, total: 100>, #<Order id: "e8f45c23...", placed_at: 2026-03-02 12:00:00 UTC, total: 250>]
```

> [!WARNING]
> While Dynamoid implements `first` and `last` to mirror Rails `ActiveRecord`, their use on large tables in production is discouraged. They are intended primarily for automated test suites and small tables. For details, see the `Dynamoid::Criteria::Chain` API documentation.

### 2.2 Retrieving Multiple Items

#### Using `all`

Use `all` to retrieve all matching items:

```ruby
# All items in the table
users = User.all

# All items matching criteria
users = User.where(active: true).all
```

Dynamoid does not materialize the entire collection in memory upfront. Instead, `all` loads items page by page on demand as you iterate, returning an `Enumerator::Lazy`. This keeps memory usage low even when querying large datasets.

To evaluate the enumerator into a standard Ruby array, call `.to_a`:

```ruby
users = User.where(active: true).all.to_a
# => [#<User id: "3a9f7216...", name: "Alice", active: true>, #<User id: "b2c89f14...", name: "Bob", active: true>]
```

#### Using `each`

You can iterate over matching items directly using `each`:

```ruby
User.where(active: true).each do |user|
  puts user.name
end
```

Like `all`, `each` streams results lazily, fetching underlying pages from DynamoDB only as needed during iteration.

### 2.3 Finding Items with PartiQL

DynamoDB supports [PartiQL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ql-reference.html), a SQL-compatible query language that allows reading and writing items using familiar SQL statements. You can execute raw `SELECT` queries through the adapter using `Dynamoid.adapter.execute`:

```ruby
results = Dynamoid.adapter.execute(
  "SELECT * FROM #{User.table_name} WHERE id = ?",
  ['3a9f7216-4726-4aea-9fbc-8554ae9292cb']
)
# => [{ id: "3a9f7216...", name: "Alice", active: true }]

results.each do |item|
  puts item[:name]
end
# Alice
```

> [!NOTE]
> Queries executed via `Dynamoid.adapter.execute` return plain Ruby hashes with symbolized keys rather than instantiated `Dynamoid::Document` model instances. In PartiQL statements, table names must match the underlying DynamoDB table name (such as `User.table_name`).

## 3. Filtering Items

Use `where` to filter items. Dynamoid accepts conditions either as a hash or as a string.

### 3.1 Hash Conditions

Passing a hash specifies equality conditions:

```ruby
users = User.where(active: true).all
# => [#<User id: "3a9f7216...", name: "Alice", active: true>]
```

When specifying multiple attributes in a hash, Dynamoid combines them with `AND` logic:

```ruby
users = User.where(name: 'Alice', active: true).all
# => [#<User id: "3a9f7216...", name: "Alice", active: true>]
```

Dynamoid automatically type-casts condition values based on the model's declared field types.

> [!NOTE]
> Hash conditions only support top-level attributes. To reference nested elements of Map or List attributes (such as `address.city` or `tags[0]`), use [string conditions](#33-string-conditions).

### 3.2 Predicate Operators

To express conditions other than equality, append an operator to the attribute name using dot notation (`attribute.operator`):

```ruby
orders = Order.where('total.gt': 50).all
# => [#<Order id: "3a9f7216...", placed_at: 2026-10-25 10:00:00 UTC, total: 99.99>]
```

Dynamoid supports the following predicate operators:

| Operator | Meaning | Example |
|---|---|---|
| `gt` | Greater than (`>`) | `'total.gt': 50` |
| `gte` | Greater than or equal (`>=`) | `'total.gte': 50` |
| `lt` | Less than (`<`) | `'total.lt': 200` |
| `lte` | Less than or equal (`<=`) | `'total.lte': 200` |
| `ne` | Not equal (`<>`) | `'name.ne': 'Alice'` |
| `between` | Value falls within range `[min, max]` | `'total.between': [50, 150]` |
| `in` | Value is included in a list | `'name.in': %w[Alice Bob]` |
| `begins_with` | String starts with prefix | `'name.begins_with': 'Al'` |
| `contains` | Substring match, or element in array/set | `'name.contains': 'li'` |
| `not_contains` | Substring or element not present | `'name.not_contains': 'admin'` |
| `null` | Attribute does not exist on the item | `'active.null': true` |
| `not_null` | Attribute exists on the item | `'active.not_null': true` |

In DynamoDB, an absent attribute is distinct from an attribute whose value is `NULL`. The `null` operator (`'active.null': true`) uses DynamoDB's `attribute_not_exists` function, matching items where the attribute does not exist. In contrast, passing `where(active: nil)` checks equality against DynamoDB's `NULL` data type, matching only items where the attribute explicitly exists with a stored `NULL` value.

Because Dynamoid omits `nil` attributes when persisting documents by default, use `'active.null': true` to find records where an attribute was left unset.

### 3.3 String Conditions

Dynamoid also supports passing conditions as a string. String conditions are written in [DynamoDB expression syntax](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.OperatorsAndFunctions.html). This format unlocks capabilities not supported by hash conditions: you can build complex boolean logic combining `OR`, `NOT`, and parenthesized groupings, query nested elements within Map and List attributes, and invoke DynamoDB functions not supported in hash syntax (such as `size` and `attribute_type`).

For example, assume a model that declares map and array fields:

```ruby
class User
  include Dynamoid::Document

  field :active, :boolean
  field :address, :map
  field :tags, :array
end
```

You can query these attributes using string conditions:

```ruby
# Complex boolean logic with AND, OR, and parentheses
User.where('active = :a AND (address.city = :c1 OR address.city = :c2)',
           a: true, c1: 'Seattle', c2: 'Portland').all

# Query a nested Map element
User.where('address.city = :city', city: 'Seattle').all

# Query a specific element in a List
User.where('tags[0] = :tag', tag: 'ruby').all

# Call DynamoDB functions like size
User.where('size(tags) > :min', min: 1).all
```

In DynamoDB expressions, values cannot be embedded as raw literals. Pass named placeholders (`:placeholder`) in the expression string and supply their values in a hash as the second argument.

> [!WARNING]
> Unlike hash conditions, Dynamoid does not automatically type-cast placeholder values in string expressions. You must supply values in the exact format expected by DynamoDB (for instance, numeric Unix epoch timestamps for datetime attributes).

### 3.4 Chaining and Merging Conditions

You can chain multiple `where` calls. Dynamoid combines all conditions using `AND` logic:

```ruby
users = User.where(active: true).where(name: 'Alice').all
# => [#<User id: "3a9f7216...", name: "Alice", active: true>]
```

You can also chain multiple conditions targeting the same attribute with different operators:

```ruby
orders = Order.where('total.gt': 50).where('total.lt': 200).all
# => [#<Order id: "3a9f7216...", placed_at: 2026-10-25 10:00:00 UTC, total: 99.99>]
```

You can also mix hash and string conditions:

```ruby
orders = Order.where(id: '3a9f7216-924b-4682-849c-f9d651a2491a')
              .where('total < :min OR total > :max', min: 10, max: 100)
              .all
```

## 4. Ordering Items

DynamoDB tables do not support arbitrary sorting by unindexed attributes. Ordering is strictly determined by the sort key defined on the table or secondary index.

By default, DynamoDB returns items in ascending order of the sort key. To reverse the order to descending, use `scan_index_forward(false)`:

```ruby
# Returns orders sorted from newest to oldest
Order.where(id: 'd7e34b12-9214-46c5-8e42-123456789abc')
  .scan_index_forward(false)
  .all
```

> [!NOTE]
> `scan_index_forward` only applies to queries that specify a partition key condition (which perform a DynamoDB `Query` operation). It has no effect on full-table `Scan` operations.

## 5. Limiting Items

Dynamoid provides two distinct methods to limit items, reflecting DynamoDB's dual evaluation model:

### `record_limit`

`record_limit` limits the number of matching items returned to your application after DynamoDB evaluates filter conditions:

```ruby
# Returns at most 10 active users
User.where(active: true).record_limit(10).all
```

Because DynamoDB evaluates filters *after* reading items from storage, Dynamoid may make multiple underlying HTTP requests until the requested number of matching items is found or the table is exhausted.

### `scan_limit`

`scan_limit` limits the number of items DynamoDB inspects during evaluation before applying filter conditions:

```ruby
# DynamoDB evaluates at most 50 items before applying the active: true filter
User.where(active: true).scan_limit(50).all
```

`scan_limit` guarantees predictable throughput and Read Capacity Unit (RCU) consumption per request, but the returned result set may contain fewer items than the limit (or zero items) if inspected items do not pass the filter.

## 6. Selecting Attributes

By default, queries fetch every attribute for each item. To reduce network payload size and memory overhead, Dynamoid provides two methods for attribute projection:

### `project`

Use `project` to retrieve only specific attributes while still instantiating `Dynamoid::Document` model instances:

```ruby
users = User.project(:name).all

user = users.first
user.name   # => "Alice"
user.active # => nil (attribute was not loaded)
```

Unprojected attributes remain unset on the model instance.

### `pluck`

Use `pluck` to extract raw attribute values without instantiating model objects:

```ruby
# Pluck a single attribute into an array of values
User.where(active: true).pluck(:name)
# => ["Alice", "Bob"]

# Pluck multiple attributes into an array of arrays
User.where(active: true).pluck(:id, :name)
# => [["3a9f7216...", "Alice"], ["b2c89f14...", "Bob"]]
```

Because `pluck` bypasses model instantiation and callback lifecycle overhead, it is significantly faster for data export and analytical processing.

## 7. Counting Items

Dynamoid provides two ways to count items, depending on whether you need an exact count of filtered items or a fast table-wide estimate:

### Approximate Table Count (`Model.count`)

Calling `count` directly on a model class returns an approximate item count retrieved from DynamoDB table statistics:

```ruby
User.count # => 15200
```

DynamoDB updates this statistic approximately every six hours. This call makes a single `DescribeTable` request and consumes zero Read Capacity Units (RCUs).

### Exact Criteria Count (`criteria.count`)

Calling `count` on a criteria chain calculates the exact number of matching items:

```ruby
User.where(active: true).count # => 42
```

This operation executes a DynamoDB `Query` or `Scan` with `Select: "COUNT"`. DynamoDB returns only the count integer without transferring item payloads, but the operation still consumes RCUs for every item evaluated.

## 8. Batching and Pagination

### `batch`

By default, DynamoDB streams results in pages sized by internal buffer limits (up to 1 MB per request). Use `batch` to control the number of items fetched per underlying HTTP request:

```ruby
User.where(active: true).batch(100).each do |user|
  # Process user
end
```

Controlling batch size helps smooth throughput consumption and bounds memory usage during background processing.

### Token-Based Pagination (`find_by_pages` and `start`)

When a query's result set exceeds 1 MB or the request limit, DynamoDB returns a `LastEvaluatedKey` token. Dynamoid exposes these native pages and tokens via `find_by_pages`:

```ruby
User.where(active: true).find_by_pages do |users, metadata|
  # users is an Array of model instances for the current page
  # metadata[:last_evaluated_key] contains the pagination token for the next page
  next_token = metadata[:last_evaluated_key]
end
```

To resume retrieval from a previous page (for example, in a paginated web API), pass the saved token to `start`:

```ruby
# First page
first_page, metadata = User.where(active: true).scan_limit(20).find_by_pages.first
next_token = metadata[:last_evaluated_key]

# Next page
second_page, _ = User.where(active: true).start(next_token).scan_limit(20).find_by_pages.first
```

## 9. Query Optimization & Indexing

### 9.1 Query vs. Scan Execution

DynamoDB provides two fundamentally distinct retrieval operations:

| Operation | When It Occurs | Performance & Cost |
|---|---|---|
| *Query* | Conditions include the **partition key** (and optionally the sort key or a secondary index). | Reads only matching items from the target partition. Fast and predictable latency. |
| *Scan* | Conditions do **not** include a partition key. | Reads every single item in the entire table, applying filters only after reading. Consumes high capacity. |

Dynamoid inspects your `where` conditions automatically:
* If the conditions include the table's partition key (or match a secondary index), Dynamoid executes an efficient `Query`.
* If the conditions contain only non-key attributes, Dynamoid must execute a full-table `Scan`.

To guard against accidental table scans in production, configure Dynamoid to log a warning or raise an exception when a scan occurs:

```ruby
Dynamoid.configure do |config|
  config.warn_on_scan = true   # Logs a warning on scan
  config.error_on_scan = true  # Raises Dynamoid::Errors::ScanProhibited
end
```

### 9.2 Automatic Index Selection

When you query using `.where(...)`, Dynamoid examines declared secondary indexes. If an index matches the queried attributes and projects all attributes (`projected_attributes: :all`), Dynamoid automatically directs the query to that index:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :active, :boolean

  global_secondary_index hash_key: :email, projected_attributes: :all
end

# Automatically executes a Query against the :email GSI instead of scanning the table
user = User.where(email: 'alice@example.com').first
```

If an index projects only keys (`:keys_only`) or a subset of attributes, Dynamoid does not select it automatically for general queries because it cannot populate all model fields without making follow-up requests.

### 9.3 Explicit Index Selection (`with_index`)

To force Dynamoid to query a specific index—such as when multiple indexes match or when using an index that projects only keys—use `with_index`:

```ruby
users = User.where(email: 'alice@example.com')
  .with_index('users_index_email')
  .all
```

### 9.4 Read Consistency

By default, DynamoDB reads are *eventually consistent*: a read immediately following a write might not yet reflect the latest update.

To ensure you read the latest data, request a *strongly consistent read*:

```ruby
# On primary key find
user = User.find('3a9f7216-4726-4aea-9fbc-8554ae9292cb', consistent_read: true)

# On query chains
users = User.where(active: true).consistent.all
```

> [!NOTE]
> Strongly consistent reads consume twice as many Read Capacity Units (RCUs) as eventually consistent reads. In DynamoDB, Global Secondary Indexes (GSIs) do not support strongly consistent reads.
