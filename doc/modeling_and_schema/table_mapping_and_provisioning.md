# Table Mapping & Provisioning

In Dynamoid, every model maps to an Amazon DynamoDB table. While Dynamoid provides sensible conventions for table names and primary keys out of the box, you can customize table identity, primary key structure, and provisioning settings using the `table` and `range` methods.

## Table Naming

By default, Dynamoid derives the DynamoDB table name by pluralizing the model class name and prepending the configured namespace:

```ruby
class User
  include Dynamoid::Document
end

User.table_name # => "<namespace>_users"
```

### Namespaces

To prevent name collisions between environments (such as development, staging, and production) or between different applications sharing an AWS account, configure a global namespace prefix:

```ruby
Dynamoid.configure do |config|
  config.namespace = 'myapp_production'
end
```

With this setting, the `User` model maps to `myapp_production_users`. In Rails applications, Dynamoid sets this default to `dynamoid_<app_name>_#{Rails.env}` (for example, `dynamoid_my_app_development`).

> [!TIP]
> For multi-account architectures, dedicated versus shared account strategies, and developer sandbox isolation, see [Table Namespaces and Environment Isolation](../configuration_and_operations/configuration_and_runtime.md#table-namespaces-and-environment-isolation) in the Configuration guide.

### Custom Table Names

To override the inferred table name for a specific model, pass the `:name` option:

```ruby
class User
  include Dynamoid::Document

  table name: :legacy_users_table
end
```

When a custom name is specified, Dynamoid still prefixes it with the configured namespace unless accessed via an ARN.

### Cross-Account and Shared Tables (ARN)

To connect to a DynamoDB table in another AWS account or region, or to reference an externally managed table without applying a namespace prefix, specify its [Amazon Resource Name (ARN)](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html) via `:arn`:

```ruby
class AuditLog
  include Dynamoid::Document

  table arn: 'arn:aws:dynamodb:us-east-1:123456789012:table/corporate_audit_logs'
end
```

DynamoDB table ARNs uniquely identify tables across AWS accounts and follow the format `arn:aws:dynamodb:<region>:<account-id>:table/<table-name>`. When `:arn` is present, it takes precedence over `:name` and ignores the `namespace` configuration option.

## Partition Key

DynamoDB requires every table to declare a *partition key* (historically called a *hash key*). The partition key value determines the physical partition where DynamoDB stores the item, and it must be unique across all items in a table with a simple primary key.

By convention, Dynamoid expects the table's partition key to be named `id` with type `:string`, and automatically declares an `id` field on the model. For string partition keys, Dynamoid automatically generates a UUID string on save if no value has been assigned. When using a numeric partition key, you must provide a value explicitly before saving.

To customize the partition key name and its data type, pass `:key` and `:key_type` to `table`:

```ruby
class User
  include Dynamoid::Document

  table key: :user_id, key_type: :integer
end
```

### Supported Types

DynamoDB requires primary key attributes (both partition and sort keys) to be scalar types—complex types such as sets, arrays, and maps cannot serve as keys. Dynamoid supports `:string` (default), `:integer`, `:number`, `:datetime`, and `:date` (as well as `:serialized` and custom types). Attempting to use an unsupported type raises a `Dynamoid::Errors::UnsupportedKeyType` exception.

For full details on type casting and custom serialization, see [Fields & Data Types](fields_and_types.md).

### Non-Default Type

Dynamoid automatically declares `field :id` as `:string` when `Dynamoid::Document` is included. If your table's `id` attribute is declared as a Number instead, simply redeclaring `field :id, :integer` triggers a warning about overriding existing accessor methods.

To declare a non-default `id` type cleanly without warnings, suppress the automatic `id` field generation using `skip_generating_fields: [:id]` before declaring your custom field:

```ruby
class User
  include Dynamoid::Document

  table skip_generating_fields: [:id]
  field :id, :integer
end
```

## Sort Key

A *composite primary key* combines a partition key with a *sort key* (historically called a *range key*). In a composite key table, multiple items can share the same partition key value as long as their sort key values differ.

To declare a sort key, use the `range` class method:

```ruby
class Order
  include Dynamoid::Document

  range :placed_at, :datetime

  field :total, :number
end
```

The second argument to `range` specifies the sort key's data type, which defaults to `:string` if omitted. Sort keys share the same scalar type restrictions as partition keys.

> [!NOTE]
> Dynamoid associations (`belongs_to`, `has_many`, `has_one`, and `has_and_belongs_to_many`) currently require simple primary keys. If your model uses a composite primary key, manage relationships through explicit queries instead of association macros.

## Table Creation and Management

Dynamoid is an application-level ORM, not an infrastructure provisioning tool. In production environments, DynamoDB tables are typically managed using Infrastructure as Code (such as Terraform, AWS CDK, or CloudFormation). Consequently, Dynamoid does not provide schema migrations or alter existing tables. It allows defining basic table properties in model classes and provides utilities to create or delete tables when needed.

### Implicit Creation

By default, Dynamoid automatically creates the underlying DynamoDB table the first time a model is saved if the table does not yet exist. This behavior is controlled by the `create_table_on_save` configuration option, which defaults to `true`.

In local development and automated test suites, automatic creation eliminates manual table setup. In production, however, table creation on save is undesirable: Dynamoid configures only basic table properties, and blocking on table creation in AWS introduces multi-second latency to user requests.

To disable auto-creation in production:

```ruby
Dynamoid.configure do |config|
  config.create_table_on_save = false
end
```

### Explicit Creation and Deletion

You can create and delete tables programmatically using model class methods:

```ruby
# Create the table in DynamoDB according to the model's schema
User.create_table # => User

# Delete the table from DynamoDB
User.delete_table # => User
```

Both `create_table` and `delete_table` are asynchronous by default and return immediately without waiting for DynamoDB to finish provisioning or deleting the table.

To wait until the operation completes before continuing, pass `sync: true`:

```ruby
# Wait until the table is created and available
User.create_table(sync: true)

# Wait until the table is completely deleted
User.delete_table(sync: true)
```

With `sync: true`, Dynamoid polls DynamoDB until the table becomes available (on creation) or is deleted (on deletion). Polling frequency and timeout are governed by two configuration options:

```ruby
Dynamoid.configure do |config|
  config.sync_retry_wait_seconds = 1  # Delay between status checks (default: 2)
  config.sync_retry_max_times = 30    # Maximum polling attempts (default: 60)
end
```

If the table does not reach the desired state within the configured attempt limit, Dynamoid logs an error and stops polling.

When creating tables, Dynamoid provisions the primary key attributes along with any Global or Local Secondary Indexes declared on the model (see [Secondary Indexes](secondary_indexes.md)).

> [!NOTE]
> When a model declares Global or Local Secondary Indexes, Dynamoid automatically creates the table synchronously. DynamoDB allows creating only one table with secondary indexes at a time, so Dynamoid waits for the table and its indexes to become available before returning.

To create tables for all declared models at once, run the provided Rake task:

```bash
rake dynamoid:create_tables
```

This task scans the directory specified by the `models_dir` configuration option (`app/models` by default), creates any missing tables along with their declared secondary indexes, skips tables that already exist, and reports the results.

### Table Settings

When Dynamoid creates a new table (whether automatically or explicitly), it applies the provisioning and schema settings declared on the model class.

> [!IMPORTANT]
> Dynamoid does not alter existing tables in DynamoDB.

#### Capacity and Billing Modes

DynamoDB supports two billing modes: *Provisioned* and *On-Demand*. You can configure this per model using the `table` method.

In on-demand mode, AWS dynamically scales throughput to match workload traffic without upfront capacity planning:

```ruby
class Session
  include Dynamoid::Document

  table capacity_mode: :on_demand
end
```

In provisioned mode, specify dedicated Read Capacity Units (RCUs) and Write Capacity Units (WCUs):

```ruby
class User
  include Dynamoid::Document

  table capacity_mode: :provisioned, read_capacity: 500, write_capacity: 200
end
```

If omitted on the model, the capacity mode and capacity units fall back to the `capacity_mode`, `read_capacity`, and `write_capacity` global configuration options. When the capacity mode is `:on_demand`, capacity settings are ignored during table creation.

#### Time To Live (TTL)

Dynamoid integrates with DynamoDB's native [Time To Live (TTL)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html) mechanism to have expired items automatically deleted. To enable it, declare the `expires` option and define a corresponding numeric field (`:integer` or `:number`):

```ruby
class Session
  include Dynamoid::Document

  table expires: { field: :ttl, after: 86_400 } # 24 hours in seconds

  field :ttl, :integer
end
```

On save, Dynamoid sets the TTL attribute to the current time plus `:after` seconds whenever the attribute value is `nil`.
