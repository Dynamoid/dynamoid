# Getting Started

Dynamoid is an Object-Document Mapper (ODM) for Amazon DynamoDB written in Ruby. It provides a familiar, ActiveRecord-like interface for Rails and standalone Ruby applications, bringing familiar ORM ergonomics to DynamoDB. Because DynamoDB fundamentally differs from relational databases, Dynamoid adapts the Active Record pattern around DynamoDB's architectural realities and performance trade-offs, while providing an idiomatic Ruby interface for DynamoDB-specific features.

A primary goal of Dynamoid is to serve as a near drop-in replacement for ActiveRecord models in Rails applications. Because it adheres to ActiveModel conventions, Dynamoid works directly with standard Rails views, form builders, and controllers. This makes migrating an existing application or building new DynamoDB-backed services straightforward, without requiring a rewrite of your application layer.

## The DynamoDB Data Model

DynamoDB stores data in *tables*, which contain *items* (analogous to rows or documents), and each item consists of *attributes* (analogous to columns or fields).

Unlike relational databases, DynamoDB tables do not enforce a column schema. The table definition specifies only the *primary key*, which uniquely identifies each item. All other attributes are dynamic—different items in the same table can carry different attributes, and an attribute only exists on an item when assigned a value.

A primary key can be either simple or composite. A *simple primary key* consists of a single *partition key* attribute (historically called a *hash key*), whose value must be unique across the entire table. A *composite primary key* combines a *partition key* with a *sort key* (historically called a *range key*); together they uniquely identify an item, so multiple items can share the same partition key value as long as their sort key values differ.

How you access data depends directly on these key attributes:

* A *point lookup* retrieves a single item directly by its primary key.
* A *query operation* retrieves items matching an exact partition key, optionally filtered by sort key conditions.
* A *scan operation* reads every item in the table when no partition key is specified.

## Key Differences from Relational Databases

Because Dynamoid provides a familiar ActiveRecord-like interface, it is easy to assume that DynamoDB behaves like a relational database underneath. In practice, several architectural differences shape how you model and query your data.

### Schemas, Primary Keys, and Writes

In PostgreSQL or MySQL, table schemas define every column and data type upfront. DynamoDB tables, by contrast, only declare their primary keys at the database level—non-key attributes are schemaless, so adding, renaming, or removing attributes does not require database migrations.

Primary keys also behave differently during writes:

* DynamoDB does not auto-generate primary keys or sequences; key values must always be provided on write.
* Primary keys are immutable once written; changing a key requires creating a new item and deleting the original.
* Updates and deletes must target an exact primary key—there is no equivalent to `UPDATE ... WHERE` or `DELETE ... WHERE`.

### Querying and Indexing

Relational databases provide an expressive query engine with automated index planning, dynamic sorting, random-access pagination, and server-side aggregation. DynamoDB trades this flexibility for predictable, single-digit millisecond latency at any scale, resulting in several fundamental constraints:

* Fast queries require an equality condition on the *partition key*, optionally refined with range conditions on the *sort key*.
* Filtering efficiently by other attributes requires defining a secondary index with those attributes as the index key.
* Results can only be sorted by the sort key—there is no arbitrary `ORDER BY` on non-key attributes.
* Result sets are traversed forward using cursors—there is no numeric `OFFSET` to skip a given number of items.
* There is no `GROUP BY` or server-side aggregation (`SUM`, `AVG`, `MIN`, `MAX`); totals must be computed in application code.
* Reads are *eventually consistent* by default and may briefly return stale data after a write unless you request a *strongly consistent read*.

### Relationships and Joins

DynamoDB does not support database-level `JOIN` operations. Instead of normalizing data across tables and joining on foreign keys, relationships must be resolved through separate lookups or by denormalizing related data into a single item.

DynamoDB also does not enforce foreign key constraints at the storage level. Because the database does not verify that referenced items exist, deleting a target item without updating its references can leave dangling foreign keys, and there is no database-level cascading deletion or nullification (`ON DELETE CASCADE` or `ON DELETE SET NULL`). Referential integrity between related items must be coordinated by the application layer.

### Transactions and Locking

In relational databases, you can open an interactive transaction block (`BEGIN` ... `COMMIT`), acquire a pessimistic lock on rows with `SELECT ... FOR UPDATE`, run business logic in Ruby, and conditionally commit or roll back.

DynamoDB does not support interactive transactions or pessimistic locking. While it provides multi-item ACID transactions, they must execute as a single, all-or-nothing request—you cannot hold a transaction or row lock open while application code reads data and decides what to do next. Instead, concurrent updates are coordinated using conditional writes (which enable optimistic locking) or atomic update operations.

### Operational Limits

DynamoDB also enforces several hard operational limits:

* An item cannot exceed 400 KB in total size ([including attribute names and values](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CapacityUnitCalculations.html)).
* A single query or scan request returns at most 1 MB of data per page.
* Batch writes and deletes are capped at 25 items per request; batch reads and transactions are capped at 100 items.

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
| Field declaration (`field :name`) | Attribute | Defines typed getters, setters, type casting, and defaults |
| Instance methods (`user.save`, `user.destroy`) | Item operations | Persists, updates, or deletes the individual item in DynamoDB |
| Class methods (`User.find`, `User.where`) | Table read operations | Performs point lookups (`GetItem`), index queries (`Query`), or scans |

Instead of constructing low-level AWS SDK parameter hashes (such as `client.put_item(item: { ... })`), you interact with DynamoDB through expressive domain objects:

```ruby
user = User.new(name: 'Alice', email: 'alice@example.com')
user.save
```

### Declaring Models and Fields

Relational databases maintain a table schema that an ORM can inspect to define attribute accessors automatically. Because DynamoDB is schemaless, schema is defined at the application layer.

To declare a model, include `Dynamoid::Document` in a Ruby class and declare each attribute with `field`:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :age, :integer
  field :active, :boolean, default: true
end
```

Fields default to `:string`, so specifying the type for string attributes is optional. Declaring a field automatically generates reader, writer (`name=`), predicate (`name?`), raw reader (`name_before_type_cast`), and dirty-tracking methods:

```ruby
user = User.new(name: 'Alice', active: true)
user.name    # => "Alice"
user.name = 'Alicia'
user.active? # => true
```

If a DynamoDB item contains attributes not declared in your Ruby model, Dynamoid ignores them when loading the item into memory. When saving, Dynamoid only writes declared, modified attributes, leaving any undeclared attributes in DynamoDB intact.

### Conventions and Defaults

Dynamoid follows *convention over configuration*, so a model only needs to declare its fields:

* Table names are derived from the pluralized class name (`User` &rarr; `users`) and prefixed with `config.namespace`.
* The primary key defaults to a string partition key named `id`, populated with a random UUID on save if unset.
* Models automatically include and maintain `created_at` and `updated_at` datetime fields.

> [!NOTE]
> To customize these defaults—such as specifying a custom table name, configuring a custom partition key name or type, or declaring a sort key for a composite primary key—refer to [Table Mapping & Provisioning](modeling_and_schema/table_mapping_and_provisioning.md).

## Basic CRUD Operations

Everyday persistence operations mirror ActiveRecord closely:

### Creating

To instantiate a new model in memory and persist it to DynamoDB, call `new` and `save`:

```ruby
user = User.new(name: 'Alice', email: 'alice@example.com')
user.age = 30
user.save
```

To instantiate and save a model in a single call, use `create`:

```ruby
user = User.create(name: 'Bob', email: 'bob@example.com', age: 25)
```

> [!NOTE]
> For advanced persistence patterns—such as bulk imports with `.import`, atomic counters, conditional updates, and optimistic locking—refer to [Persistence](working_with_data/persistence.md).

### Reading and Querying

To look up an item directly by its primary key, use `find`:

```ruby
user = User.find(user_id)
```

To query items by attribute conditions, use `where`:

```ruby
active_users = User.where(active: true).all
adult        = User.where('age.gte': 18).first
```

> [!NOTE]
> For more query capabilities—including range conditions, attribute projection, consistent reads, and pagination—refer to [Query Interface](working_with_data/query_interface.md).

### Updating

To modify attributes on a loaded model and persist the changes in one step, call `update_attributes`:

```ruby
user.update_attributes(age: 31)
```

You can also assign attributes directly and call `save`:

```ruby
user.age = 31
user.save
```

### Deleting

To remove a loaded model instance and run its `destroy` callbacks, call `destroy`:

```ruby
user.destroy
```

To delete an item directly by its primary key without instantiating the model or running callbacks, call `delete`:

```ruby
User.delete(user_id)
```

## Validations

You can declare validation rules on a model to verify its state before it is saved to DynamoDB:

```ruby
class User
  include Dynamoid::Document

  field :name
  validates :name, presence: true
end

user = User.new
user.valid?               # => false
user.errors.full_messages # => ["Name can't be blank"]
user.save                 # => false
```

## Lifecycle Callbacks

You can register callbacks to run logic before, around, or after events in a model's lifecycle (such as `save`, `create`, `update`, and `destroy`):

```ruby
class User
  include Dynamoid::Document

  field :email

  before_save :normalize_email

  private

  def normalize_email
    self.email = email.downcase if email.present?
  end
end
```

> [!NOTE]
> For the full list of lifecycle events, execution order, and how to halt operations from a callback, refer to [Callbacks](working_with_data/callbacks.md).

## Table Creation

Unlike relational databases, DynamoDB is schemaless, so Dynamoid does not use database migration files. By default, new tables are automatically created when a model is saved for the first time, or can be pre-created in batch using a [Rake task](#rake-tasks). To learn more, see [Table Creation and Management](modeling_and_schema/table_mapping_and_provisioning.md#table-creation-and-management).

## Installation and Configuration

To add Dynamoid to your application, include the gem in your `Gemfile` and run `bundle install`:

```ruby
gem 'dynamoid'
```

Next, set up your database connection depending on your environment.

### Local Development

For local development and automated testing without an AWS account, start [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html) via Docker:

```bash
docker run --rm -d -p 8000:8000 amazon/dynamodb-local
```

Then create `config/initializers/dynamoid.rb` to connect to the local container with dummy credentials. Using `Rails.env` in `config.namespace` keeps development and test tables isolated:

```ruby
Dynamoid.configure do |config|
  config.namespace  = "my_app_#{Rails.env}"
  config.endpoint   = 'http://localhost:8000'
  config.region     = 'us-east-1'
  config.access_key = 'fake'
  config.secret_key = 'fake'
end
```

> [!NOTE]
> By default, DynamoDB Local runs purely in memory—all tables and data are discarded when the container stops. If you need data to persist between launches, you must explicitly configure DynamoDB Local to write to disk and configure a [Docker volume](https://docs.docker.com/engine/storage/volumes/) to preserve those files on your host machine. For setup instructions, refer to [Deploying DynamoDB Local with Docker](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.DownloadingAndRunning.html).

### AWS Environments

When connecting to Amazon DynamoDB, credentials and region are automatically discovered from standard environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`), AWS profiles, or IAM roles:

```ruby
Dynamoid.configure do |config|
  config.namespace = 'my_app'
end
```

The `config.namespace` option prefixes table names (e.g., `my_app_users`). Because DynamoDB table names are shared across an entire AWS account, this prefix prevents collisions between different environments (such as `staging` vs. `test`) or developers sharing a sandbox account.

> [!NOTE]
> For advanced configuration options—including custom credentials, IAM role assumption, HTTP timeouts, and retry backoff strategies—refer to [Configuration](configuration.md).

### Rake Tasks

Dynamoid ships with Rake tasks for verifying connectivity and provisioning tables locally.

To test network connectivity and authentication with DynamoDB:

```bash
rake dynamoid:ping
```

To create tables (along with any declared secondary indexes) for all models in [`config.models_dir`](configuration.md#configmodels_dir) (`app/models` by default), skipping tables that already exist:

```bash
rake dynamoid:create_tables
```

In Rails applications, these tasks are loaded automatically. In standalone Ruby projects, define an `:environment` task that configures Dynamoid and require `dynamoid/tasks` in your `Rakefile`:

```ruby
Rake::Task.define_task(:environment) do
  require_relative 'config/boot'
end

require 'dynamoid/tasks'
```

{{#include _includes/feedback.md}}
