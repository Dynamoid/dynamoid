# Secondary Indexes (GSI & LSI)

DynamoDB requires a partition key (or partition + sort key) to perform fast, direct item lookups. If you need to search or filter items by attributes that are not part of the primary key without performing an expensive, full-table **Scan**, you must define a **Secondary Index**.

Dynamoid supports both types of DynamoDB secondary indexes:
1. **Global Secondary Index (GSI):** An index with a partition key and an optional sort key that can be different from those on the base table.
2. **Local Secondary Index (LSI):** An index that has the same partition key as the base table, but a different sort key.

> [!NOTE]
> Unlike base table primary keys, secondary indexes do not enforce uniqueness constraints. Multiple items in the base table can share identical index partition keys and sort keys without conflict or overwriting one another.

## Defining a Global Secondary Index (GSI)

To declare a GSI, use the `global_secondary_index` class method. Indexes must be declared **after** the corresponding fields are defined:

```ruby
class Post
  include Dynamoid::Document

  field :title, :string
  field :category, :string
  field :published_at, :datetime

  # GSI with partition key only
  global_secondary_index hash_key: :category

  # GSI with composite key (hash key + range key)
  global_secondary_index hash_key: :category,
                         range_key: :published_at,
                         name: 'posts_category_published_at_index',
                         projected_attributes: :all
end
```

### Available GSI Options

* `:hash_key` *(Required)* - Attribute name used as the index partition key.
* `:range_key` - Attribute name used as the index sort key.
* `:name` - The index name in DynamoDB. If omitted, Dynamoid generates a descriptive name automatically.
* `:projected_attributes` - Which attributes to copy into the index:
  * `:keys_only` (default) - Only index keys and the table's primary key are copied.
  * `:all` - All attributes from the base table are projected into the index.
  * `[:attr1, :attr2]` - An array of specific attribute names to project.
* `:read_capacity` - Provisioned Read Capacity Units for the index (defaults to `Dynamoid::Config.read_capacity`).
* `:write_capacity` - Provisioned Write Capacity Units for the index (defaults to `Dynamoid::Config.write_capacity`).

---

## Defining a Local Secondary Index (LSI)

A Local Secondary Index uses the base table's partition key, but allows querying across an alternate sort key:

```ruby
class Comment
  include Dynamoid::Document

  table key: :post_id
  range :comment_id

  field :author, :string
  field :score, :integer

  # Alternate sort key for comments on the same post
  local_secondary_index range_key: :score, projected_attributes: :all
end
```

> **Note on LSIs:** DynamoDB requires Local Secondary Indexes to be created when the table is created. You cannot add an LSI to an existing table in DynamoDB.

---

## Projected Attributes & The "Complete Document" Rule

In DynamoDB, queries on an index can only read attributes that are projected into that index.

> **Important:** To allow Dynamoid to automatically use a GSI during normal `.where(...)` queries, you **must set `projected_attributes: :all`**.

If an index uses `:keys_only` or projects only a subset of attributes, Dynamoid will not select it automatically for general queries because it cannot return fully populated model instances without making a second query back to the base table.

```ruby
class User
  include Dynamoid::Document

  field :email, :string
  field :age, :integer

  # Allows implicit .where(email: '...') to use this GSI
  global_secondary_index hash_key: :email, projected_attributes: :all
end
```

---

## Querying with Secondary Indexes

Dynamoid provides two ways to query secondary indexes: **implicit selection** and **explicit selection**.

### 1. Implicit Index Selection

When you query with `.where(...)`, Dynamoid analyzes the query attributes and checks whether they match a declared index with `projected_attributes: :all`. If a matching index is found, Dynamoid automatically executes an efficient DynamoDB `Query` against that index instead of scanning the table:

```ruby
# Automatically uses the GSI on :email
user = User.where(email: 'alice@example.com').first

# Automatically uses a composite GSI (category + published_at)
recent_news = Post.where(category: 'news', 'published_at.gte': 1.week.ago).all
```

### 2. Explicit Index Selection (`with_index`)

If you want to force Dynamoid to query a specific index (for instance, when multiple indexes share the same keys, or when using an index that projects only keys), use `.with_index`:

```ruby
posts = Post.where(category: 'tech')
  .with_index('posts_category_published_at_index')
  .all
```

### 3. Controlling Sort Direction

For indexes that include a sort (range) key, you can reverse the sort order using `.scan_index_forward(false)` (descending order):

```ruby
# Returns posts from newest to oldest
latest_posts = Post.where(category: 'tech')
  .with_index('posts_category_published_at_index')
  .scan_index_forward(false)
  .all
```
