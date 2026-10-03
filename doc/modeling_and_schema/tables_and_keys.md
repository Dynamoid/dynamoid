# Tables & Primary Keys

In DynamoDB, a table is the foundational data container, and every item in a table is uniquely identified by its primary key. Dynamoid provides sensible conventions for table names, keys, and throughput out of the box, while allowing full customization through the `table` and `range` class methods.

```ruby
class User
  include Dynamoid::Document

  table name: :awesome_users, key: :user_id, read_capacity: 5, write_capacity: 5
end
```

> **Important (ORM vs. Table Provisioning):** Capacity and schema settings specified in your model only apply when Dynamoid **creates a new table** in DynamoDB (for instance, via `rake dynamoid:create_tables` or automatic table creation in tests). Dynamoid is an application-level ORM and **does not alter or mutate existing tables** in AWS. If a table already exists in DynamoDB, Dynamoid expects its schema to match what your model defines.

---

## Table Naming & Namespaces

By default, Dynamoid infers the table name from the pluralized model class name:

```ruby
class Customer
  include Dynamoid::Document
  # Maps to DynamoDB table 'customers' (or '<namespace>_customers')
end
```

### Table Namespaces

To prevent collisions between environments (development, staging, test) or between different applications sharing the same AWS account, you can configure a global namespace in an initializer:

```ruby
Dynamoid.configure do |config|
  config.namespace = 'myapp_production'
end
```

With this configuration, the `Customer` model maps to `myapp_production_customers`. In Rails applications, Dynamoid defaults to `dynamoid_#{application_name}_#{Rails.env}`.

### Custom Table Names

To override the default table name:

```ruby
class User
  include Dynamoid::Document

  table name: :legacy_users_table
end
```

### Cross-Account and Shared Tables (ARN)

If you need to connect to a DynamoDB table in another AWS account, region, or with an externally managed name that should bypass the namespace prefix, specify its Amazon Resource Name (ARN) via `:arn`:

```ruby
class AuditLog
  include Dynamoid::Document

  table arn: 'arn:aws:dynamodb:us-east-1:123456789012:table/corporate_audit_logs'
end
```

When `:arn` is provided, it takes precedence over `:name` and ignores `Dynamoid::Config.namespace`.

---

## Primary Keys

DynamoDB supports two types of primary keys:
1. **Simple Primary Key:** A single Partition Key (Hash Key).
2. **Composite Primary Key:** A Partition Key (Hash Key) paired with a Sort Key (Range Key).

### 1. Partition Key Configuration

By default, Dynamoid defines a partition key named `id` with type `string`. You can customize both the attribute name and its data type:

```ruby
class Customer
  include Dynamoid::Document

  table key: :customer_id, key_type: :integer
end
```

* `:key` - The name of the partition key attribute (defaults to `:id`).
* `:key_type` - The data type of the partition key attribute (`:string`, `:integer`, or `:number`). Defaults to `:string`.

#### Customizing the Default `:id` Type

If you keep the default attribute name `:id` but want it to be an integer (e.g. for external sequential identifiers), declare the `:id` field explicitly with its type:

```ruby
class Account
  include Dynamoid::Document

  field :id, :integer
end
```

### 2. Composite Primary Keys (Sort Key)

Along with a partition key, a table may have a **sort key** (also called a range key). To declare a sort key, use the `range` class method:

```ruby
class Order
  include Dynamoid::Document

  table name: :orders, key: :customer_id, key_type: :integer
  range :order_id, :string

  field :total, :number
end
```

The second argument to `range` specifies the data type (defaults to `:string`):

```ruby
class Post
  include Dynamoid::Document

  range :posted_at, :datetime
end
```

You can also pass field options to `range`:

```ruby
class Metric
  include Dynamoid::Document

  range :recorded_at, :datetime, store_as_string: true
end
```

### Querying Composite Keys

When a table has a composite primary key, both keys are required to retrieve a specific item:

```ruby
# Retrieve an order by its partition key and sort key
order = Order.find_by_composite_key(1042, 'ord-99812')
```

For range finding queries using conditions like `.gt`, `.lt`, and `.between`, see [Query Interface](../working_with_data/query_interface.md).

---

## Capacity and Billing Modes

DynamoDB offers two billing modes: **Provisioned** and **On-Demand**. You can configure this mode per model or globally via `Dynamoid::Config.capacity_mode`.

### On-Demand Capacity Mode

In on-demand mode, AWS automatically scales throughput to match workload demand without provisioning capacity:

```ruby
class EventLog
  include Dynamoid::Document

  table capacity_mode: :on_demand
end
```

> When `capacity_mode` is `:on_demand`, the `read_capacity` and `write_capacity` options are ignored.

### Provisioned Capacity Mode

For workloads with predictable traffic, provisioned mode specifies dedicated Read Capacity Units (RCUs) and Write Capacity Units (WCUs):

```ruby
class HighThroughputMetric
  include Dynamoid::Document

  table capacity_mode: :provisioned, read_capacity: 500, write_capacity: 200
end
```

If not specified, capacity units default to `Dynamoid::Config.read_capacity` (default: 100) and `Dynamoid::Config.write_capacity` (default: 20).

---

## Built-in Table Features

### Time To Live (TTL)

Dynamoid supports DynamoDB's [Time To Live (TTL)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html) mechanism. When an `expires` option is declared, Dynamoid automatically sets the expiration timestamp on item creation if one has not been provided manually:

```ruby
class Session
  include Dynamoid::Document

  table expires: { field: :ttl, after: 86_400 } # Expires after 24 hours (in seconds)

  field :ttl, :integer
end
```

* The field used for TTL (`ttl` in this example) must be declared explicitly.
* The field must be numeric (`integer` or `number`), or `datetime` stored as a number.

### Disabling Timestamps

By default, Dynamoid automatically declares `created_at` and `updated_at` fields and updates them on save. You can disable timestamps for a specific table:

```ruby
class ReadOnlySnapshot
  include Dynamoid::Document

  table timestamps: false
end
```

### Single Table Inheritance (STI)

To customize the attribute name used to store subclass types for Single Table Inheritance:

```ruby
class Vehicle
  include Dynamoid::Document

  table inheritance_field: :vehicle_type
end
```

See [Single Table Inheritance](single_table_inheritance.md) for details.

### Suppressing Generated Fields

To prevent Dynamoid from implicitly defining accessor methods for standard fields:

```ruby
class RawItem
  include Dynamoid::Document

  table skip_generating_fields: %i[id created_at updated_at]
end
```

---

## Summary of `table` Options

| Option | Type | Default | Description |
|---|---|---|---|
| `:name` | `Symbol`, `String` | Pluralized model class name | The name of the DynamoDB table. |
| `:arn` | `String` | `nil` | Table ARN; allows accessing tables across AWS accounts or regions. Takes precedence over `:name`. |
| `:key` | `Symbol` | `:id` | Name of the partition key attribute. |
| `:key_type` | `Symbol` | `:string` | Type of the partition key (`:string`, `:integer`, `:number`). |
| `:capacity_mode` | `Symbol` | `:provisioned` | Billing mode: `:provisioned` or `:on_demand`. |
| `:read_capacity` | `Integer` | `100` | Read capacity units (used during table creation; ignored if `:on_demand`). |
| `:write_capacity` | `Integer` | `20` | Write capacity units (used during table creation; ignored if `:on_demand`). |
| `:timestamps` | `Boolean` | `true` | Whether to automatically generate and maintain `created_at` and `updated_at`. |
| `:expires` | `Hash` | `nil` | TTL configuration: `{ field: :attr_name, after: <seconds> }`. |
| `:inheritance_field` | `Symbol` | `:type` | Discriminator attribute for Single Table Inheritance. |
| `:skip_generating_fields` | `Array<Symbol>` | `[]` | List of implicit fields to not generate accessors for. |
