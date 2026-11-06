# Query Interface

If you are accustomed to querying DynamoDB with the AWS SDK, retrieving data typically requires constructing low-level parameter hashes for operations like `GetItem`, `BatchGetItem`, `Query`, and `Scan`. Dynamoid provides an expressive, chainable query interface modeled after Active Record, abstracting low-level SDK calls while adapting to DynamoDB's partitioning and indexing model.

Similar to Active Record relations, Dynamoid queries evaluate lazily. Calling query methods like `where` builds a chainable query without executing network requests against DynamoDB until you iterate over results, access an item, or call an execution method such as `all` or `each`.

```ruby
query = User.where(active: true)

query.each do |user|
  puts user.name
end
```

Code examples throughout this guide refer to the following models:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :active, :boolean
end

class OrderItem
  include Dynamoid::Document

  table key: :order_id
  range :position, :integer
  field :product_id
  field :quantity, :integer
end
```

The `User` model represents a simple primary key table using Dynamoid's default `id` partition key. The `OrderItem` model represents a composite primary key table: `table key: :order_id` declares a custom partition key (without needing an explicit `field` call), and `range :position, :integer` defines the sort key. For details on declaring primary keys, see [Partition Key](../modeling_and_schema/table_mapping_and_provisioning.md#partition-key).

## Retrieving Items

Dynamoid provides finder methods to look up individual items by primary key or iterate over collections from a table.

### Retrieving a Single Item

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
order_item = OrderItem.find(order_id, range_key: 1)
# => #<OrderItem order_id: "d7e34b12...", position: 1, product_id: "c3d4e5f6...", quantity: 2>
```

For composite primary keys, retrieve multiple items by passing an array of `[partition_key, sort_key]` pairs:

```ruby
order_items = OrderItem.find([[order_id, 1], [order_id, 2]])
# => [#<OrderItem order_id: "d7e34b12...", position: 1, product_id: "c3d4e5f6...", quantity: 2>, #<OrderItem order_id: "d7e34b12...", position: 2, product_id: "e8f45c23...", quantity: 1>]
```

### Retrieving Multiple Items

Use `all` or `each` to retrieve an entire table or filtered results:

```ruby
# Returns an Enumerator::Lazy of all items in the table
users = User.all

# Query matching items
users = User.where(active: true).all

# Iterate directly
User.where(active: true).each do |user|
  puts user.name
end
```

Dynamoid does not materialize the entire collection in memory upfront. Instead, `all` and `each` stream items lazily, fetching underlying pages from DynamoDB on demand during iteration to keep memory usage low.

To evaluate results into a standard Ruby array immediately, call `.to_a`:

```ruby
users = User.where(active: true).all.to_a
# => [#<User id: "3a9f7216...", name: "Alice", active: true>, #<User id: "b2c89f14...", name: "Bob", active: true>]
```

### Strongly Consistent Reads

By default, DynamoDB read operations are [eventually consistent](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html). A read request performed immediately after a write might return stale data while changes propagate across DynamoDB storage partitions. When your application requires the latest data, you can request strongly consistent reads.

For single-item lookups and batch retrieval with `find`, pass `consistent_read: true`:

```ruby
user = User.find(user_id, consistent_read: true)
```

When building a query, append `consistent`:

```ruby
users = User.where(active: true).consistent.all
```

> [!NOTE]
> Strongly consistent reads consume double the Read Capacity Units (RCUs) of eventually consistent reads. In addition, DynamoDB does not support strongly consistent reads on Global Secondary Indexes (GSIs).

## Filtering Items

Use `where` to filter items, passing conditions either as a hash or as a string. Which attributes and operators you provide determines whether Dynamoid executes a fast partition `Query` or a full-table `Scan` (see [When Query and Scan Execute](#when-query-and-scan-execute)).

### Hash Conditions

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

To express conditions other than equality, append an operator to the attribute name using dot notation (`attribute.operator`):

```ruby
order_items = OrderItem.where('quantity.gt': 1).all
# => [#<OrderItem order_id: "3a9f7216...", position: 1, product_id: "c3d4e5f6...", quantity: 2>]
```

Dynamoid supports the following predicate operators:

| Operator | Meaning | Example |
|---|---|---|
| `gt` | Greater than (`>`) | `'quantity.gt': 5` |
| `gte` | Greater than or equal (`>=`) | `'quantity.gte': 5` |
| `lt` | Less than (`<`) | `'quantity.lt': 20` |
| `lte` | Less than or equal (`<=`) | `'quantity.lte': 20` |
| `ne` | Not equal (`<>`) | `'name.ne': 'Alice'` |
| `between` | Value falls within range `[min, max]` | `'quantity.between': [5, 15]` |
| `in` | Value is included in a list | `'name.in': %w[Alice Bob]` |
| `begins_with` | String starts with prefix | `'name.begins_with': 'Al'` |
| `contains` | Substring match, or element in array/set | `'name.contains': 'li'` |
| `not_contains` | Substring or element not present | `'name.not_contains': 'admin'` |
| `null` | Attribute does not exist on the item | `'active.null': true` |
| `not_null` | Attribute exists on the item | `'active.not_null': true` |

In DynamoDB, an absent attribute is distinct from an attribute whose value is `NULL`. The `null` operator (`'active.null': true`) uses DynamoDB's `attribute_not_exists` function, matching items where the attribute does not exist. In contrast, passing `where(active: nil)` checks equality against DynamoDB's `NULL` data type, matching only items where the attribute explicitly exists with a stored `NULL` value.

Because Dynamoid omits `nil` attributes when persisting documents by default, use `'active.null': true` to find items where an attribute was left unset.

> [!NOTE]
> Hash conditions only support top-level attributes. To reference nested elements of Map or List attributes (such as `address.city` or `tags[0]`), use [string conditions](#string-conditions).

### String Conditions

Dynamoid also supports passing conditions as a string. String conditions are written in [DynamoDB expression syntax](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.OperatorsAndFunctions.html). This format unlocks capabilities not supported by hash conditions: you can build complex boolean logic combining `OR`, `NOT`, and parenthesized groupings, query nested elements within Map and List attributes, and invoke DynamoDB functions not supported in hash syntax (such as `size` and `attribute_type`).

For example, assume the `User` model declares map and array fields:

```ruby
class User
  # ...
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

### Chaining and Merging Conditions

You can chain multiple `where` calls. Dynamoid combines all conditions using `AND` logic:

```ruby
users = User.where(active: true).where(name: 'Alice').all
# => [#<User id: "3a9f7216...", name: "Alice", active: true>]
```

You can also chain multiple conditions targeting the same attribute with different operators:

```ruby
order_items = OrderItem.where('quantity.gte': 2).where('quantity.lte': 10).all
# => [#<OrderItem order_id: "3a9f7216...", position: 1, product_id: "c3d4e5f6...", quantity: 2>]
```

You can also mix hash and string conditions:

```ruby
order_items = OrderItem.where(order_id: order_id)
                       .where('quantity < :min OR quantity > :max', min: 2, max: 10).all
```

## Querying: Query or Scan

In DynamoDB, querying is performed using either an efficient `Query` operation or a costly `Scan`. Dynamoid routes your `where` conditions to one of these operations automatically. Knowing how Dynamoid makes this choice helps you write queries with predictable latency and minimal read cost.

### When Query and Scan Execute

Dynamoid inspects conditions passed to `where` to automatically select the optimal operation:

If conditions include an equality condition on the table's partition key, Dynamoid executes an efficient `Query` reading only items within that partition. You can query the partition key alone, narrow the search with a sort key condition, or filter the partition's items by non-key attributes:

```ruby
OrderItem.where(order_id: order_id).all
OrderItem.where(order_id: order_id, 'position.gt': 1).all
OrderItem.where(order_id: order_id, quantity: 2).all
```

Without an equality condition on the partition key, Dynamoid must execute a full-table `Scan`. This applies when filtering by non-key attributes, querying a sort key alone, or using non-equality operators:

```ruby
OrderItem.where(quantity: 5).all
OrderItem.where(position: 1).all
OrderItem.where('order_id.ne': order_id).all
```

By default, Dynamoid logs a warning whenever `where` triggers a `Scan` operation, or can be configured to raise an error instead—useful, for example, in test suites to catch accidental scans (see [`config.warn_on_scan` and `config.error_on_scan`](../configuration_and_operations/configuration_and_runtime.md#complete-configuration-reference)).

> [!WARNING]
> Only hash conditions determine whether Dynamoid performs a `Query`. During a `Query` operation, string conditions cannot reference partition or sort keys (of the table or a selected secondary index)—always specify key attributes using hash conditions. In addition, sort key conditions in a `Query` only support a single condition using equality, `gt`, `gte`, `lt`, `lte`, `between`, or `begins_with`.

### Automatic Index Selection

Without an equality condition on the table's partition key, Dynamoid would normally fall back to a full-table `Scan`. However, if the model defines a secondary index whose keys match the `where` conditions, Dynamoid automatically routes the query to that index, executing an efficient `Query` instead.

To qualify for automatic selection, the index must project all table attributes in DynamoDB and be declared in the model with `projected_attributes: :all`. This ensures Dynamoid can instantiate complete models directly from the index:

```ruby
class User
  # ...
  global_secondary_index hash_key: :email, projected_attributes: :all
end

users = User.where(email: 'alice@example.com').all
# => [#<User id: "3a9f7216...", name: "Alice", email: "alice@example.com">]
```

If multiple indexes could satisfy the query, Dynamoid prefers composite key matches (partition and sort key) over partition-key-only matches. To eliminate ambiguity and explicitly choose an index, use `with_index` (see [Forcing an Index](#forcing-an-index)).

### Forcing an Index

To explicitly specify which secondary index Dynamoid should use, chain `with_index`:

```ruby
users = User.where(email: 'alice@example.com').with_index(:by_email).all
```

Where `:by_email` is the index name declared on the model:

```ruby
global_secondary_index name: :by_email, hash_key: :email, projected_attributes: :all
```

Explicit index selection is useful in several scenarios:

* When multiple secondary indexes match the query conditions and you want to ensure a specific index is queried.
* When querying an index with partial projection.
* When scanning a sparse index to read only items containing the indexed attribute, rather than scanning the entire table.

For details on declaring and naming secondary indexes, see [Secondary Indexes](../modeling_and_schema/table_mapping_and_provisioning.md#secondary-indexes).

## Ordering Items

In DynamoDB, items cannot be sorted by arbitrary attributes. Ordering is strictly determined by the sort key defined on the table or secondary index.

By default, DynamoDB returns items in ascending order of the sort key. You can control sort direction with `scan_index_forward`: pass `false` for descending order, or `true` to specify ascending order explicitly.

For example, querying `OrderItem` by partition key returns items sorted by its sort key (`position`):

```ruby
# Returns order items sorted by position in descending order (2, 1)
order_items = OrderItem.where(order_id: order_id).scan_index_forward(false).all
# => [
#      #<OrderItem order_id: "3a9f7216...", position: 2, product_id: "e8f45c23...", quantity: 1>,
#      #<OrderItem order_id: "3a9f7216...", position: 1, product_id: "c3d4e5f6...", quantity: 2>
#    ]
```

Because items are sorted only within a specific partition, ordering requires a partition key condition and is not supported in full table `Scan` operations.

> [!WARNING]
> DynamoDB sorts strings strictly by UTF-8 binary byte order rather than locale-aware collation. For details on sort order across data types, see the [DynamoDB Query API documentation](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html).

## Selecting Attributes

By default, queries fetch every attribute for each item. When working with large items or fetching collections, transferring unneeded attributes increases network latency and memory usage. Dynamoid provides two methods to select specific attributes: `project` and `pluck`.

### `project`

Use `project` to retrieve only specific attributes while still receiving model instances. Unprojected attributes are initialized to `nil` on the loaded models:

```ruby
users = User.project(:name).all

user = users.first
user.name   # => "Alice"
user.active # => nil
```

Like `where`, `project` can be chained with other query methods:

```ruby
users = User.project(:id, :name).where(active: true).all
# => [#<User id: "3a9f7216...", name: "Alice", email: nil, active: nil, ...>, ...]
```

### `pluck`

Use `pluck` to extract attribute values directly as Ruby arrays without instantiating model objects:

```ruby
# Pluck a single attribute into an array of values
User.where(active: true).pluck(:name)
# => ["Alice", "Bob"]

# Pluck multiple attributes into an array of arrays
User.where(active: true).pluck(:id, :name)
# => [["3a9f7216...", "Alice"], ["b2c89f14...", "Bob"]]
```

Unlike `project`, `pluck` immediately executes the query and returns an `Array`. Because it skips model instantiation and lifecycle tracking, `pluck` is significantly faster and uses less memory when extracting data for exports or analytical processing.

## Limiting Results

Dynamoid provides two methods to limit query results depending on your application's needs: `scan_limit` (to keep read costs strictly bounded) and `record_limit` (to retrieve a specific number of matching items).

When a query has no filter conditions, every scanned item is a match, so both methods behave identically. When filtering items, they serve different purposes.

### `scan_limit`

Use `scan_limit` when you need predictable performance and want to limit how much data DynamoDB inspects in storage.

```ruby
# Inspects at most 50 items from storage, returning only those that are active
users = User.where(active: true).scan_limit(50).all
```

Because DynamoDB applies filters *after* inspecting items, `scan_limit` guarantees your query will never exceed a set read cost. However, the returned collection may contain fewer items than the limit—or even zero—if few or none of the inspected items pass the filter.

Use `scan_limit` in background jobs, rate-limited tasks, or whenever predictable latency and cost are more important than getting a full page of results.

### `record_limit`

Use `record_limit` when your application logic or UI requires a specific number of matching items, similar to `LIMIT` in SQL.

```ruby
# Returns up to 10 active users
users = User.where(active: true).record_limit(10).all
# => [#<User id: "3a9f7216...", name: "Alice", active: true>, ...]
```

Dynamoid continues fetching items in the background until it collects the requested number of matching items or reaches the end of the data.

> [!WARNING]
> When filtering on attributes with sparse matches, `record_limit` may perform multiple network requests behind the scenes to find enough matching items, leading to higher latency and read costs.

## Pagination and Batching

DynamoDB divides query and scan results into pages. Dynamoid provides methods to control page sizes during iteration and to implement cursor-based pagination across requests.

### `batch`

By default, DynamoDB retrieves up to 1 MB of data per request. Use `batch` to limit the number of items fetched in each underlying network request:

```ruby
User.where(active: true).batch(1000).each do |user|
  # Process user
end
```

This is especially useful when iterating over large collections (such as in background jobs, data migrations, or processing pipelines). Without a batch size, unconstrained requests can cause sudden spikes in Read Capacity Unit (RCU) consumption and risk throughput throttling.

Like `scan_limit`, `batch` limits how many items DynamoDB inspects before filtering on each request, smoothing RCU consumption over time and keeping application memory usage low. Consequently, when filters are present, each yielded batch may contain fewer matching items than the specified size (or even zero).

### `find_by_pages`

Unlike relational databases, DynamoDB does not support offset-based pagination. Instead, it relies on [cursors](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.Pagination.html): queries return results in pages of up to 1 MB of data per request, along with a cursor to resume the query if more items remain.

Dynamoid handles this through two complementary methods:
* `find_by_pages` queries data one native DynamoDB page at a time, yielding the loaded models and a cursor.
* `start` resumes a query from a cursor.

Unlike `all`, `each`, or `batch`—which automatically loop through subsequent pages behind the scenes—`find_by_pages` gives you direct control over network calls: each page corresponds to exactly one DynamoDB request.

```ruby
User.where(active: true).find_by_pages do |users, metadata|
  # Process page of users
end
```

When a web application exposes pagination, clients can fetch large result sets page by page at their own pace. The client retains the returned cursor and sends it back in subsequent requests, keeping the application completely stateless.

Without a block, `find_by_pages` returns a lazy enumerator to query pages (with a cursor) on demand:

```ruby
pages = User.where(active: true).find_by_pages
users, metadata = pages.first
```

To query subsequent pages, pass the cursor to `start`:

```ruby
cursor = metadata[:last_evaluated_key]

next_pages = User.where(active: true).start(cursor).find_by_pages
next_users, next_metadata = next_pages.first
```

When the final page is reached and no further items remain, `metadata[:last_evaluated_key]` is `nil`.

Use `batch` or `scan_limit` to limit items per page:

```ruby
pages = User.where(active: true).batch(25).find_by_pages
```

When processing large datasets in background jobs, methods like `all` or `batch.each` execute network requests continuously, which can quickly exhaust read capacity and cause throughput throttling. Because each yield of `find_by_pages` corresponds to exactly one DynamoDB network call, you can throttle throughput by inserting a pause (such as `sleep`) inside the block between requests.

## Finding Items with PartiQL

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

{{#include ../_includes/feedback.md}}

