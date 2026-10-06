# Getting Started with Dynamoid

Dynamoid is an Object-Document Mapper (ODM) for Amazon DynamoDB written in Ruby. It provides a familiar, ActiveRecord-like interface for Rails and standalone Ruby applications, bringing familiar ORM ergonomics to DynamoDB. Because DynamoDB fundamentally differs from relational databases, Dynamoid adapts the Active Record pattern around DynamoDB's architectural realities and performance trade-offs, while providing an idiomatic Ruby interface for DynamoDB-specific features.

A primary goal of Dynamoid is to serve as a near drop-in replacement for ActiveRecord models in Rails applications. Because it adheres to ActiveModel conventions, Dynamoid works directly with standard Rails views, form builders, and controllers. This makes migrating an existing application or building new DynamoDB-backed services straightforward, without requiring a rewrite of your application layer.

## The DynamoDB Data Model

DynamoDB stores data in *tables*, which contain *items* (analogous to rows or documents), and each item consists of *attributes* (analogous to columns or fields).

Unlike relational databases, DynamoDB tables do not enforce a column schema. The table definition specifies only the *primary key*, which uniquely identifies each item. All other attributes are dynamic—different items in the same table can carry different attributes, and an attribute only exists on an item when assigned a value.

The primary key is composed of one or two attributes:

* A *simple primary key* consists of a single attribute serving as the *partition key* (historically called a *hash key*). The value of this attribute must be unique across the entire table.
* A *composite primary key* is composed of two attributes: a *partition key* attribute and a *sort key* attribute (historically called a *range key*). The combination of both values forms the unique item identifier—multiple items can share the same partition key value as long as their sort key values differ.

How you access data depends directly on these key attributes:

* A *point lookup* retrieves a single item directly by its primary key.
* A *query operation* retrieves items matching an exact partition key, optionally filtered by sort key conditions.
* A *scan operation* reads every item in the table whenever a search does not specify a partition key.

## Key Differences from Relational Databases

Because Dynamoid provides a familiar ActiveRecord-like interface, it is easy to assume that DynamoDB behaves like a relational database underneath. In practice, several architectural differences shape how you model and query your data.

### Schemas and Primary Keys

In PostgreSQL or MySQL, table schemas define every column and data type upfront. DynamoDB tables, by contrast, only declare their primary keys at the database level—non-key attributes are schemaless, so adding, renaming, or removing attributes does not require database migrations.

An item's primary key (both the partition key and sort key) is strictly immutable once written. Unlike relational databases where primary key columns can technically be updated in place, changing an item's primary key in DynamoDB requires creating a new item and deleting the original.

### Querying and Indexing

In SQL, a query planner analyzes your `WHERE` clauses and automatically selects the best index. DynamoDB has no query planner:

* Fast queries require an equality condition on the *partition key*, optionally refined with range conditions on the *sort key*.
* To filter efficiently by other attributes, you must define a secondary index (where those attributes serve as the index key) and target that index explicitly by name.
* Results can only be sorted by the sort key defined on the table or index—there is no arbitrary `ORDER BY` on non-key attributes.
* Pagination is forward-only. Unlike relational databases that support numeric `OFFSET` to jump to arbitrary pages, DynamoDB only allows traversing results sequentially from one page to the next, with no backward pagination.
* There are no database-level aggregation functions (`SUM`, `AVG`, `MIN`, `MAX`). Finding totals or summary metrics requires calculating them in application code or maintaining pre-computed counter attributes with atomic increments.
* Unlike relational databases that guarantee immediate read-after-write consistency, DynamoDB reads (point lookups and queries) are *eventually consistent* by default—a read right after a write might briefly return stale data. When up-to-date data is required, you can request a *strongly consistent read* to guarantee seeing the latest write.

### Relationships and Joins

DynamoDB does not support database-level `JOIN` operations. Instead of normalizing data across tables and joining on foreign keys, relationships must be resolved through separate lookups or by denormalizing related data into a single item.

### Transactions

In relational databases, you can open an interactive transaction block (`BEGIN` ... `COMMIT`), read data, run business logic in Ruby, and conditionally commit or roll back.

DynamoDB does not support interactive transactions. While it does support multi-item ACID transactions, they must execute as a single, coordinated, all-or-nothing request. You cannot hold a transaction open while application code queries data and decides what to do next.

### Operational Limits

DynamoDB also enforces several hard operational limits:

* Items cannot exceed 400 KB in total size, including all attribute names and values combined. Larger payloads or file attachments should be offloaded to external storage like Amazon S3.
* A single query or scan operation returns at most 1 MB of data before pausing, requiring pagination even if a requested item limit has not yet been met.
* Native batch writes and deletes are capped at 25 items per request, while batch reads and transactions are limited to 100 items.

## The Active Record Pattern in Dynamoid

Dynamoid adapts the *Active Record* pattern, an architectural approach to database access originally cataloged by Martin Fowler in his [patterns catalog](https://martinfowler.com/eaaCatalog/activeRecord.html) and popularized in the Ruby community by Ruby on Rails.

In this pattern, an object encapsulates both database access and domain logic. Rather than separating domain models from a persistence layer (such as repositories or data mappers) or writing low-level database queries by hand, an Active Record model unites four core responsibilities:

* *State* — holds an individual item's attributes in memory and exposes typed accessors.
* *Persistence* — saves changes and deletes items directly through instance methods (such as `user.save` and `user.destroy`).
* *Querying* — retrieves items through class-level finders such as `User.find` and `User.where`.
* *Domain logic* — enforces validation rules and business methods directly on the model alongside its data.

### Mapping Active Record to DynamoDB

In relational implementations of Active Record (such as ActiveRecord in Rails), models map classes to tables, rows to instances, and columns to object attributes. Dynamoid adapts these exact same principles to Amazon DynamoDB:

| Ruby / Dynamoid | DynamoDB Concept | Role |
|---|---|---|
| Model class (`User`) | Table (`users`) | Maps to the table; coordinates queries and table-level configuration |
| Model instance (`user = User.new`) | Item | Represents an individual item in memory and holds its attributes |
| Field declaration (`field :name`) | Attribute | Defines typed getters, setters, type coercion, and defaults |
| Instance methods (`user.save`, `user.destroy`) | Item operations | Persists, updates, or deletes the individual item in DynamoDB |
| Class methods (`User.find`, `User.where`) | Table read operations | Performs point lookups (`GetItem`), index queries (`Query`), or scans |

Instead of constructing low-level AWS SDK parameter hashes (such as `client.put_item(item: { ... })`), you interact with DynamoDB through expressive domain objects:

```ruby
user = User.new(name: 'Alice', email: 'alice@example.com')
user.save # Validates attributes and persists the model
```

### Why Fields Must Be Explicitly Declared

Relational databases maintain a table schema that an ORM can inspect to define attribute accessors automatically.

Because DynamoDB is schemaless, there is no database column catalog to inspect—so Dynamoid defines schema at the application layer:

* You explicitly declare each attribute with `field`, specifying its name, optional data type (defaulting to `:string`), and optional defaults.
* Dynamoid generates reader, writer (`name=`), predicate (`name?`), raw reader (`name_before_type_cast`), and dirty-tracking methods for each declared field.
* If a DynamoDB item contains attributes that are not declared in your Ruby model, Dynamoid ignores them when loading the item into memory. When updating an existing model, Dynamoid only writes changed attributes, leaving any undeclared attributes on the item in DynamoDB intact.

## Anatomy of a Dynamoid Model

To declare a model, create a Ruby class, include the `Dynamoid::Document` module, and declare its attributes using the `field` method:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :age, :integer
  field :active, :boolean, default: true
end
```

Fields default to the `:string` type, so declaring the type for string attributes (`field :name`) is optional.

Declaring a field automatically generates reader, writer (`name=`), and predicate (`name?`) methods:

```ruby
user = User.new(name: 'Alice', active: true)
user.name    # => "Alice"
user.name = 'Alicia'

# Predicate methods check presence or boolean truthiness
user.active? # => true
```

### Conventions and Defaults

Dynamoid follows *convention over configuration*, so a conventional model only needs to declare its fields:

* Table names are automatically derived from the pluralized class name (`User` &rarr; `users`), prefixed by any configured namespace (`config.namespace`).
* The primary key defaults to a partition key named `id` of type `string`. When saving a new model, Dynamoid assigns an auto-generated UUID string if no `id` is specified.
* Timestamps are maintained automatically: Dynamoid generates `created_at` and `updated_at` datetime fields on every model by default.

> [!NOTE]
> To customize these defaults—such as specifying a custom table name, configuring a custom partition key name or type, or declaring a sort key for a composite primary key—refer to [Tables & Primary Keys](modeling_and_schema/tables_and_keys.md).

## Basic CRUD Operations

Everyday persistence operations mirror ActiveRecord closely:

### Creating and Persisting Records

You can instantiate a model and persist it in two steps, or initialize and save it in a single call:

```ruby
# Instantiate a new in-memory model
user = User.new(name: 'Alice', email: 'alice@example.com')
user.new_record? # => true
user.persisted?  # => false

# Persist to DynamoDB
user.age = 30
user.save        # => true (or false if validations fail)

user.new_record? # => false
user.persisted?  # => true

# The partition key is automatically assigned if omitted
user.id          # => "8b9e6f1a-7b3c-4d5e-9f0a-1b2c3d4e5f6a"

# Or instantiate and save in a single call
user = User.create(name: 'Bob', email: 'bob@example.com', age: 25)

# Bang variants raise an exception on failure instead of returning false
user = User.create!(name: 'Bob', email: 'bob@example.com', age: 25)
```

The bang variants (`save!` and `create!`) raise `Dynamoid::Errors::DocumentNotValid` if validations fail (described in [Validations](#validations)), or `Dynamoid::Errors::RecordNotSaved` if a `before_*` callback cancels persistence by throwing `:abort`.

> [!NOTE]
> For advanced persistence patterns—such as bulk imports with `.import`, atomic counters, conditional updates, and optimistic locking—refer to [Persistence & Mutations](working_with_data/persistence_and_mutations.md).

### Reading and Finding Records

Dynamoid provides methods for both point lookups by primary key and multi-record queries:

```ruby
# Look up by simple partition key (raises Dynamoid::Errors::RecordNotFound if missing)
user = User.find(user_id)

# Find multiple records by primary key in a single request
users = User.find('id1', 'id2')
users = User.find(['id1', 'id2'])

# Check existence without loading items into memory
User.exists?(user_id)                   # => true
User.exists?(email: 'alice@example.com') # => true

# Query records using criteria chains
active_users = User.where(active: true).all
adult        = User.where('age.gte': 18).first
user         = User.where(email: 'alice@example.com').first
```

If you prefer `find` to return `nil` instead of raising an exception when an item is not found, pass `raise_error: false`:

```ruby
user = User.find('missing-id', raise_error: false) # => nil
```

> [!NOTE]
> For more query capabilities—including range conditions, attribute projection, consistent reads, and pagination—refer to [Query Interface](working_with_data/query_interface.md).

### Updating Records

Modifying attributes and persisting changes follows the standard patterns:

```ruby
# Update attributes and save in one step (runs validations and callbacks)
user.update_attributes(age: 31)

# Or modify attributes directly and call save
user.age = 31
user.save

# Update a single attribute directly without running validations
user.update_attribute(:active, false)

# Reload attributes from DynamoDB
user.reload
```

### Deleting Records

You can remove individual records or clear matching criteria in bulk:

```ruby
# Destroy an individual record (runs :destroy callbacks)
user.destroy
user.destroyed? # => true

# Delete an individual record directly (skips callbacks)
user.delete

# Delete all matching records in batch (skips callbacks)
User.where(active: false).delete_all
```

## Validations

Dynamoid includes `ActiveModel::Validations`, providing the full suite of standard Rails validators—including `presence`, `numericality`, `inclusion`, `length`, and `format`, as well as custom validation methods:

```ruby
class Product
  include Dynamoid::Document

  field :sku
  field :price, :number
  field :inventory_count, :integer

  validates :sku, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :inventory_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

Checking validity populates the `errors` collection just like in ActiveRecord:

```ruby
product = Product.new(price: -5)
product.valid? # => false

product.errors[:sku]         # => ["can't be blank"]
product.errors[:price]       # => ["must be greater than 0"]
product.errors.full_messages # => ["Sku can't be blank", "Price must be greater than 0"]
```

Calling `save` on an invalid model returns `false`, while bang methods (`save!`, `create!`, `update!`) raise `Dynamoid::Errors::DocumentNotValid`:

```ruby
product.save  # => false
product.save! # Raises Dynamoid::Errors::DocumentNotValid
```

If you need to bypass validations when saving, pass `validate: false`:

```ruby
product.save(validate: false)
```

> [!NOTE]
> Dynamoid does not support uniqueness validations (such as `validates_uniqueness_of`) because DynamoDB cannot enforce uniqueness on non-key attributes without scanning the entire table. Enforce uniqueness using dedicated lookup tables or DynamoDB transactions instead.

## Lifecycle Callbacks

Dynamoid integrates `ActiveModel::Callbacks`, providing hooks into the persistence lifecycle:

| Lifecycle Phase | Available Hooks |
|---|---|
| Validation | `before_validation`, `after_validation` |
| Save | `before_save`, `around_save`, `after_save` |
| Create | `before_create`, `around_create`, `after_create` |
| Update | `before_update`, `around_update`, `after_update` |
| Destroy | `before_destroy`, `around_destroy`, `after_destroy` |
| Object State | `after_initialize`, `after_find`, `after_touch` |

Callbacks can be defined with method symbols, blocks, or dedicated callback objects. Throwing `:abort` within any `before_*` callback stops execution and cancels the action:

```ruby
class Order
  include Dynamoid::Document

  field :total, :number
  field :reference_number

  # Register callbacks with a method symbol:
  before_save :calculate_totals
  after_create :notify_warehouse
  after_destroy :audit_log_deletion

  # Or using a block for short, inline operations:
  before_validation on: :create do
    self.reference_number ||= SecureRandom.hex(8).upcase
  end

  private

  def calculate_totals
    # ...
  end

  def notify_warehouse
    # ...
  end

  def audit_log_deletion
    # ...
  end
end
```

## Dirty Attribute Tracking

Dynamoid implements the `ActiveModel::Dirty` interface to track in-memory attribute modifications before they are persisted:

```ruby
user = User.find('user-101') # Initially, user.name is 'Alex'
user.name_changed?          # => false

user.name = 'Alexander'
user.name_changed?          # => true
user.name_was               # => "Alex"
user.changes                # => { "name" => ["Alex", "Alexander"] }

user.save
user.name_changed?          # => false
```

For more dirty tracking methods—including reverting changes with `restore_attributes` or inspecting previous changes—refer to the `Dynamoid::Dirty` API documentation.

## Installation & Configuration

To add Dynamoid to your application, include the gem in your `Gemfile` and run `bundle install`:

```ruby
gem 'dynamoid'
```

In a Rails application, create `config/initializers/dynamoid.rb` depending on your environment:

### Local Development with DynamoDB Local

For local development and testing without an AWS account, configure a local endpoint with dummy credentials. Using `Rails.env` in `config.namespace` keeps local development and test tables separate:

```ruby
Dynamoid.configure do |config|
  config.namespace  = "my_app_#{Rails.env}"
  config.endpoint   = 'http://localhost:8000'
  config.region     = 'us-east-1'
  config.access_key = 'fake'
  config.secret_key = 'fake'
end
```

### Connecting to AWS

When connecting to Amazon DynamoDB, credentials and region are automatically discovered from standard environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`), AWS profiles, or IAM roles:

```ruby
Dynamoid.configure do |config|
  config.namespace = 'my_app'
end
```

The `config.namespace` option prefixes table names (e.g., `my_app_users`). Because DynamoDB table names are shared across an entire AWS account, this prefix prevents collisions between different environments (such as `staging` vs. `test`) or developers sharing a sandbox account.

Once configured, you can interact with your models directly in `bin/rails console`.

> [!NOTE]
> For advanced configuration options—including custom credentials, IAM role assumption, HTTP timeouts, and retry backoff strategies—refer to [Configuration & Runtime](configuration_and_operations/configuration_and_runtime.md).

## Next Steps

Now that you have a solid grasp of Dynamoid's data model, conventions, and lifecycle, you can continue with these essential guides:

* [Fields & Data Types](modeling_and_schema/fields_and_types.md) — Explore supported data types, collections, and custom serializers.
* [Query Interface](working_with_data/query_interface.md) — Master criteria chaining, scans versus queries, and pagination.
* [Persistence & Mutations](working_with_data/persistence_and_mutations.md) — Perform atomic updates, bulk imports, and optimistic locking.

