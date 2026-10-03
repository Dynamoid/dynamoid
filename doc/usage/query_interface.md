# Query Interface

Dynamoid provides a rich query interface inspired by ActiveRecord, while adapting to the unique architecture and performance characteristics of Amazon DynamoDB.

```ruby
# Find by primary key
user = User.find(user_id)

# Filter by criteria
users = User.where(city: 'Chicago', active: true).all
```

---

## The Fundamental Concept: Query vs. Scan

In DynamoDB, data retrieval is fundamentally divided into two operations:

| Operation | When It Occurs | Performance & Cost |
|---|---|---|
| **Query** | When your criteria includes a condition on the **Partition Key** (and optionally the Sort Key or a Secondary Index). | **Fast & Cheap.** DynamoDB jumps directly to the partition and reads only matching items. Predictable single-digit millisecond latency. |
| **Scan** | When your criteria does **not** include a partition key condition. | **Slow & Expensive.** DynamoDB reads every single item in the entire table, applying filters only after reading the items. Consumes significant read capacity. |

Dynamoid automatically decides whether to execute a `Query` or a `Scan` based on the conditions you provide:
* If your `.where(...)` includes the table's partition key (or matches a GSI), Dynamoid performs a **Query**.
* If your `.where(...)` queries only non-key attributes, Dynamoid must perform a **Scan**.

> **Tip:** You can configure Dynamoid to warn you or raise an error whenever a full-table Scan is triggered by setting `config.warn_on_scan = true` or `config.error_on_scan = true`.

---

## Finding Records

### Finding by Primary Key

```ruby
# Simple primary key
user = User.find('3a9f7216-4726-4aea-9fbc-8554ae9292cb')

# Multiple IDs (executes BatchGetItem)
users = User.find(%w[id-1 id-2 id-3])

# Composite primary key (partition key + sort key)
order = Order.find_by_composite_key(customer_id, order_id)
```

### Dynamic Finders

Dynamoid supports dynamic finder methods for simple attribute lookups:

```ruby
user = User.find_by_email('alice@example.com')
```

---

## Filtering with `.where`

### 1. Hash Syntax (Recommended for Keys)

Hash conditions provide automatic type casting and enable Dynamoid to detect key attributes for efficient `Query` operations:

```ruby
User.where(active: true, department: 'Engineering').all
```

### 2. String Condition Expressions

For complex boolean logic, built-in functions, or comparisons, you can pass a DynamoDB condition expression string with named parameters:

```ruby
Address.where('city = :c AND age >= :min_age', c: 'Chicago', min_age: 21).all
```

> **Warning:** Attributes in string condition expressions are evaluated as DynamoDB filter expressions. To ensure Dynamoid performs a `Query` rather than a `Scan`, always specify partition key conditions using the Hash syntax.

---

## Sort Key & Range Conditions

When querying a table (or index) with a composite primary key, you can optimize retrieval using range conditions:

```ruby
# Greater than / Less than
Order.where(customer_id: 42, 'placed_at.gt': 1.week.ago).all
Order.where(customer_id: 42, 'placed_at.lt': 1.month.ago).all

# Greater than or equal / Less than or equal
Metric.where(server_id: 'srv-1', 'timestamp.gte': start_time).all
Metric.where(server_id: 'srv-1', 'timestamp.lte': end_time).all

# Between a range
Event.where(user_id: 10, 'created_at.between': [start_date, end_date]).all

# String prefix match
User.where(organization_id: 'org-1', 'last_name.begins_with': 'Sm').all
```

DynamoDB allows at most one range condition per query.

---

## Filter Operators on Non-Key Attributes

Dynamoid supports several operators for filtering non-key attributes on the DynamoDB side:

```ruby
# Inclusion
Address.where('city.in': %w[London Edinburgh Manchester]).all

# String contains / not contains
Post.where('title.contains': 'DynamoDB').all
Post.where('tags.not_contains': 'deprecated').all

# Attribute existence (checking presence, not value)
User.where('phone_number.not_null': true).all
User.where('deleted_at.null': true).all
```

> **Note on `nil` attributes:** By default, Dynamoid does not store `nil` values in DynamoDB items. Thus, `null` checks whether the attribute exists on the document. If `store_attribute_with_nil_value: true` is configured, use `where(attribute: nil)` instead.

---

## Read Consistency

By default, DynamoDB reads are **eventually consistent**: a read immediately following a write might not immediately reflect the latest update.

If your application requires reading the latest data immediately, request a **strongly consistent read**:

```ruby
# On find
user = User.find(id, consistent_read: true)

# In query chains
users = User.where(active: true).consistent.all
```

> **Note:** Strongly consistent reads consume twice as many Read Capacity Units (RCUs) as eventually consistent reads.

---

## Selecting Specific Fields (`project`)

To reduce network bandwidth and memory overhead, use `.project` to retrieve only specific attributes:

```ruby
users = User.project(:name, :email).all

user = users.first
user.name       # => "Alice"
user.email      # => "alice@example.com"
user.created_at # => nil (not retrieved)
```

---

## Limits & Batching

You can fine-tune query performance using three types of limits:

* `record_limit(n)` - Limits the number of evaluated matching records returned to your application.
* `scan_limit(n)` - Limits the number of items DynamoDB inspects during evaluation before stopping.
* `batch(size)` - Controls the number of items requested per underlying HTTP request to avoid large payloads.

```ruby
# Retrieve only the first 10 matching users
User.where(active: true).record_limit(10).all

# Process large datasets in manageable chunks without consuming excessive memory
User.batch(100).each(&:sync_with_crm!)
```

---

## Pagination (`find_by_pages` and `.start`)

DynamoDB uses token-based pagination. If a query returns more data than fits in a single response (or hits the 1 MB limit), it returns a `LastEvaluatedKey`.

You can access low-level DynamoDB pages and metadata using `find_by_pages`:

```ruby
class UsersController < ApplicationController
  def index
    # Decode next-page token if provided
    start_key = params[:cursor] ? JSON.parse(Base64.urlsafe_decode64(params[:cursor])) : nil

    # Fetch page
    page_records, metadata = User.where(active: true)
      .start(start_key)
      .find_by_pages
      .first

    render json: {
      users: page_records,
      next_cursor: metadata[:last_evaluated_key] ? Base64.urlsafe_encode64(metadata[:last_evaluated_key].to_json) : nil
    }
  end
end
```
