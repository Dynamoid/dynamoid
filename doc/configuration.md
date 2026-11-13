# Configuration

Dynamoid provides application-wide settings for AWS credentials, HTTP networking, retry policies, table provisioning defaults, and field serialization.

## Overview

Application settings can be declared in a configuration block or inspected and modified directly at runtime:

```ruby
require 'dynamoid'

Dynamoid.configure do |config|
  config.namespace = 'myapp'
  config.region    = 'us-west-2'
end

Dynamoid.config.namespace # => "myapp"
Dynamoid.config.region = 'us-east-1'
```

### Ruby on Rails Applications

In Rails applications, place the configuration block in an initializer:

```ruby
# config/initializers/dynamoid.rb
Dynamoid.configure do |config|
  # ...
end
```

When running in Rails, Dynamoid automatically routes log messages to `Rails.logger` and derives a default namespace: `"dynamoid_#{app_name}_#{Rails.env}"`.

### Standalone Ruby Applications

In standalone scripts, background workers, or non-Rails web frameworks, configure Dynamoid before loading models or issuing queries:

```ruby
# bootstrap.rb
require 'dynamoid'

Dynamoid.configure do |config|
  # ...
end
```

In standalone Ruby applications, Dynamoid logs to `$stdout` and defaults `config.namespace` to `'dynamoid'`.

## Connection & Authentication

Dynamoid communicates with DynamoDB using the official AWS SDK for Ruby, which by default discovers credentials and region through the SDK's [configuration resolution chain](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/environment-variables.html) by evaluating environment variables, AWS configuration profiles (`~/.aws/credentials`), or IAM roles.

To isolate Dynamoid from your global AWS configuration or connect to a local development emulator, you can configure connection parameters directly.

### config.access_key and config.secret_key

* *Default:* `nil`
* *Type:* `String`

Sets static AWS access key ID and secret access key strings directly on the Dynamoid client:

```ruby
config.access_key = ENV['DYNAMODB_ACCESS_KEY_ID']
config.secret_key = ENV['DYNAMODB_SECRET_ACCESS_KEY']
```

Configuring these settings directly is helpful when your application uses static credentials specific to DynamoDB, without altering global AWS configuration. For dynamic, temporary, or role-based credentials, use `config.credentials` instead.

### config.region

* *Default:* `nil`
* *Type:* `String`

Specifies the AWS region hosting your DynamoDB tables (such as `'us-west-2'` or `'eu-central-1'`):

```ruby
config.region = 'us-west-2'
```

When left as `nil`, the underlying AWS SDK attempts to resolve the region automatically from `ENV['AWS_REGION']`, `ENV['AWS_DEFAULT_REGION']`, or `~/.aws/config`.

### config.credentials

* *Default:* `nil`
* *Type:* `Aws::Credentials` or any object responding to `#credentials`

An object-based alternative to `config.access_key` and `config.secret_key`. While `access_key` and `secret_key` accept static string pairs, `config.credentials` accepts an AWS SDK credential provider object. This is typically used when authentication requires temporary session tokens, dynamic credential rotation, or AWS STS role assumption:

```ruby
sts_client = Aws::STS::Client.new(region: 'us-west-2')

role_credentials = Aws::AssumeRoleCredentials.new(
  client: sts_client,
  role_arn: 'arn:aws:iam::123456789012:role/DynamoDBAppRole',
  role_session_name: 'dynamoid-production'
)

config.credentials = role_credentials
```

For other supported credential classes, see the [AWS SDK Credential Providers documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/credential-providers.html).

When `config.credentials` is specified, it takes precedence and causes Dynamoid to ignore `config.access_key` and `config.secret_key`.

### config.endpoint

* *Default:* `nil`
* *Type:* `String`

Overrides the default AWS DynamoDB service URL. This setting is typically used during development and automated testing to direct database traffic to a local emulator, such as DynamoDB Local or LocalStack:

```ruby
config.endpoint = 'http://localhost:8000'
```

When set to `nil`, requests are routed to the standard public AWS DynamoDB endpoint for the configured region.

## HTTP Client

Dynamoid executes database requests through an underlying AWS SDK client. You can configure HTTP timeouts and proxies to control connection lifecycles and network routing.

These options are passed directly to [`Aws::DynamoDB::Client`](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#initialize-instance_method). When left as `nil` (the default), Dynamoid defers to the built-in defaults of the AWS SDK for Ruby.

### config.http_open_timeout

* *Default:* `nil` (AWS SDK default: `15`)
* *Type:* `Integer` or `Float`

The maximum number of seconds to wait when establishing a new TCP connection to DynamoDB before timing out:

```ruby
config.http_open_timeout = 2
```

### config.http_read_timeout

* *Default:* `nil` (AWS SDK default: `60`)
* *Type:* `Integer` or `Float`

The maximum number of seconds to wait for a response from DynamoDB after sending a request before raising an HTTP read timeout exception:

```ruby
config.http_read_timeout = 5
```

### config.http_idle_timeout

* *Default:* `nil` (AWS SDK default: `5`)
* *Type:* `Integer` or `Float`

The number of seconds a persistent connection can remain idle in the client connection pool before being closed and discarded:

```ruby
config.http_idle_timeout = 10
```

Setting this to a higher value keeps connections alive longer, reducing SSL/TLS handshake overhead for background workers or high-throughput processes.

### config.http_continue_timeout

* *Default:* `nil` (AWS SDK default: `1`)
* *Type:* `Integer` or `Float`

The number of seconds to wait for an HTTP `100-continue` response from DynamoDB before uploading the request payload:

```ruby
config.http_continue_timeout = 1
```

### config.http_proxy

* *Default:* `nil`
* *Type:* `String` or `URI`

A proxy URI string used to route all HTTP/HTTPS requests to DynamoDB:

```ruby
config.http_proxy = 'http://proxy.corp.example.com:8080'
```

When set to `nil`, requests are dispatched directly, or follow standard proxy environment variables (`HTTPS_PROXY` or `HTTP_PROXY`) if configured in your environment.

## Table Namespaces

Because DynamoDB table names are global within each AWS account and region, any two models that resolve to the same table name will target the same physical DynamoDB table.

Dynamoid allows configuring a namespace prefix to isolate tables across environments, applications, and test suites.

### config.namespace

* *Default:* `"dynamoid_#{app_name}_#{Rails.env}"` in Rails; `'dynamoid'` in standalone Ruby applications
* *Type:* `String` or `nil`

Prepends a prefix to all model table names, joined by an underscore (for example, `<namespace>_<table_name>`):

```ruby
config.namespace = 'myapp_production'

User.table_name # => "myapp_production_users"
```

To omit prefixes and use clean table names, set `config.namespace` to `nil`:

```ruby
config.namespace = nil

User.table_name # => "users"
```

How you configure `config.namespace` depends on your AWS account architecture:

* *Shared AWS accounts* — when development, test, and staging environments share an AWS account, dynamic namespaces prevent data collisions:
  ```ruby
  config.namespace = "myapp_#{ENV.fetch('APP_ENV', 'development')}"
  ```
* *Dedicated AWS accounts* — when production and staging run in separate AWS accounts (the recommended AWS security architecture), table name prefixes are redundant. Setting `config.namespace = nil` keeps table names simple (`users`, `orders`).
* *Parallel test runners* — when executing tests concurrently across multiple workers (such as `parallel_tests` or multiple CI containers), incorporate the process or worker ID to isolate tables:
  ```ruby
  worker_id = ENV['TEST_ENV_NUMBER'] || Process.pid
  config.namespace = "myapp_test_#{worker_id}"
  ```

For model-level table name overrides and ARN mapping, see [Table Mapping & Provisioning](modeling_and_schema/table_mapping_and_provisioning.md).

## Throttling & Backoff Strategies

Dynamoid's backoff mechanism controls retry delays during batch operations:

* *Batch writes* (`Model.import`) — retries unprocessed items returned when a table exceeds its write capacity.
* *Batch reads* (`Model.find([ids])`) — retries unprocessed keys returned when a table exceeds its read capacity.

If none of the items in a batch can be processed, DynamoDB returns a throttling error, which the underlying AWS SDK automatically retries using its built-in backoff mechanism. However, when an operation is partially successful—processing some items while returning others as unprocessed—the SDK does not retry. In this scenario, Dynamoid retries the remaining items itself. Configuring `config.backoff` introduces delays between these retries to pace requests and prevent immediate tight loops that sustain table throttling.

By default, `config.backoff` is `nil`, meaning Dynamoid retries unprocessed batch items immediately without waiting between attempts.

### config.backoff

* *Default:* `nil`
* *Type:* `Symbol`, `Hash`, or `nil`

Selects the active backoff strategy and its parameters. Dynamoid provides two built-in strategies: `:constant` and `:exponential`.

Use `:constant` to pause for a fixed duration between retries (`1` second by default):

```ruby
config.backoff = :constant
```

Pass a hash to configure a custom delay in seconds:

```ruby
config.backoff = { constant: 2 }
```

Use `:exponential` (truncated binary exponential backoff) to progressively double the wait time up to a ceiling (`base_backoff: 0.5` seconds and `ceiling: 3` by default):

```ruby
config.backoff = :exponential
```

Pass a hash to customize `base_backoff` and `ceiling`:

```ruby
config.backoff = { exponential: { base_backoff: 0.2, ceiling: 5 } }
```

During exponential backoff, the delay for retry attempt `n` is calculated as `base_backoff * (2 ** [n - 1, ceiling - 1].min)`.

### config.backoff_strategies

* *Default:* `{ constant: BackoffStrategies::ConstantBackoff, exponential: BackoffStrategies::ExponentialBackoff }`
* *Type:* `Hash{Symbol => #call}`

A registry of available backoff algorithms. A strategy generator must be a callable object (such as a `Proc` or class implementing `.call`) that accepts optional configuration arguments and returns a callable object that executes the delay:

```ruby
config.backoff_strategies[:jitter] = lambda do |max_seconds = 3|
  -> { sleep(rand * max_seconds) }
end
```

Once registered, activate the custom strategy via `config.backoff`:

```ruby
config.backoff = { jitter: 5 }
```

## Table Provisioning

When Dynamoid creates DynamoDB tables, you can configure application-wide defaults for billing modes, throughput capacity, and synchronization timeouts. These settings provide fallbacks whenever a model does not specify them explicitly (see [Table Settings](modeling_and_schema/table_mapping_and_provisioning.md#table-settings)).

### config.create_table_on_save

* *Default:* `true`
* *Type:* `Boolean`

When enabled (the default), saving a model instance automatically checks whether the physical DynamoDB table exists and creates it synchronously if missing.

While convenient for local development and testing, creating tables on the fly during normal write traffic introduces latency and risks table creation errors in multi-process production deployments. In production environments, disable auto-creation and provision tables upfront (see [Table Creation and Management](modeling_and_schema/table_mapping_and_provisioning.md#table-creation-and-management)):

```ruby
config.create_table_on_save = false
```

### config.capacity_mode

* *Default:* `nil` (DynamoDB defaults to `:provisioned`)
* *Type:* `Symbol` or `nil` (`:provisioned` or `:on_demand`)

Sets the default billing mode for tables created by Dynamoid:

```ruby
config.capacity_mode = :on_demand
```

When set to `:on_demand`, DynamoDB automatically accommodates workloads as they ramp up or down without specifying read or write capacity units.

### config.read_capacity and config.write_capacity

* *Default:* `read_capacity = 100`, `write_capacity = 20`
* *Type:* `Integer`

Sets the baseline Read Capacity Units (RCU) and Write Capacity Units (WCU) allocated to newly created tables when operating in `:provisioned` mode:

```ruby
config.read_capacity  = 50
config.write_capacity = 10
```

These values can be overridden on individual models using the `table` method.

### config.sync_retry_max_times and config.sync_retry_wait_seconds

* *Default:* `sync_retry_max_times = 60`, `sync_retry_wait_seconds = 2`
* *Type:* `Integer`

Controls polling behavior when creating tables synchronously (via [`create_table(sync: true)`](modeling_and_schema/table_mapping_and_provisioning.md#explicit-creation-and-deletion) or when [`create_table_on_save`](#configcreate_table_on_save) is enabled).

Because DynamoDB table creation is asynchronous, Dynamoid polls table status until the table becomes active or the retry limit is reached:

```ruby
config.sync_retry_wait_seconds = 1
config.sync_retry_max_times    = 30
```

### config.models_dir

* *Default:* `'./app/models'`
* *Type:* `String`

Specifies the directory path where Dynamoid model files are stored:

```ruby
config.models_dir = './lib/my_app/models'
```

The `rake dynamoid:create_tables` task scans this directory recursively to discover and load all model classes before provisioning tables.

For full details on table provisioning and index configuration, see [Table Mapping & Provisioning](modeling_and_schema/table_mapping_and_provisioning.md).

## Query & Scan Safeguards

In Amazon DynamoDB, a Query operation looks up items efficiently using an equality condition on a partition key (either on the table or a secondary index). When a query's `where` conditions do not specify a partition key, DynamoDB falls back to a Scan operation, reading every item in the entire table.

On large tables, unexpected scans consume massive read capacity, incur unexpected AWS costs, and degrade application latency. Dynamoid provides configuration safeguards to detect and prevent accidental scans.

### config.warn_on_scan

* *Default:* `true`
* *Type:* `Boolean`

Logs a warning message whenever a query with `where` conditions falls back to a Scan operation:

```ruby
config.warn_on_scan = true
```

When enabled, calling `where` without a partition key condition emits a warning:

```text
WARN -- : Queries without an index are forced to use scan and are generally much slower than indexed queries!
WARN -- : You can index this query by adding index declaration to user.rb:
```

> [!NOTE]
> `warn_on_scan` triggers only when `where` conditions are present (such as `User.where(role: 'admin')`). Explicit, unconditioned table scans such as `User.all` do not emit warnings.

### config.error_on_scan

* *Default:* `false`
* *Type:* `Boolean`

Raises an exception whenever a query with `where` conditions falls back to a Scan operation:

```ruby
config.error_on_scan = true
```

Enabling `error_on_scan` in automated test suites and staging environments is recommended to catch accidental table scans before they reach production.

Like `warn_on_scan`, `error_on_scan` only raises when `where` conditions are present (such as `User.where(...)`); it does not prevent intentional full-table scans such as `User.all`.

For detailed querying patterns and index strategies, see [Query Interface](working_with_data/query_interface.md).

## Storage & Field Defaults

These settings define application-wide defaults for field persistence, type casting, time zones, and serialization. Many of these global options can be overridden on individual model fields (for example, `field :logged_at, :datetime, store_as_string: true`).

### config.timestamps

* *Default:* `true`
* *Type:* `Boolean`

Controls whether Dynamoid automatically declares and manages `created_at` and `updated_at` datetime fields on all models:

```ruby
config.timestamps = false
```

When set to `false`, timestamps are disabled globally unless enabled on individual models via `table timestamps: true`. For model-level overrides and automatic timestamp tracking, see [Timestamps](modeling_and_schema/fields_and_data_types.md#timestamps).

### config.application_timezone and config.dynamodb_timezone

* *Default:* `:utc` for both
* *Type:* `Symbol` (`:utc`, `:local`) or `String` (e.g., `'America/New_York'`)

Controls how time zones are handled when loading and persisting `datetime` attributes.

`config.application_timezone` sets the time zone to which `datetime` attributes are converted when loaded into application memory. It accepts `:utc` (the default), `:local` (the host system's time zone), or any named time zone string (such as `'America/New_York'`, or `Time.zone.name` in Rails):

```ruby
config.application_timezone = 'America/New_York'
```

`config.dynamodb_timezone` defines the time zone used when persisting timestamps as ISO-8601 formatted strings in DynamoDB (when `store_datetime_as_string` is enabled):

```ruby
config.dynamodb_timezone = :utc
```

### config.store_datetime_as_string and config.store_date_as_string

* *Default:* `false` for both
* *Type:* `Boolean`

Governs the DynamoDB wire format used for `datetime` and `date` attributes.

By default, `datetime` fields are stored as numeric seconds since epoch with nanosecond precision, and `date` fields are stored as integer days since epoch. When set to `true`, values are stored as ISO-8601 formatted strings (`"YYYY-MM-DDTHH:MM:SSZ"` and `"YYYY-MM-DD"`):

```ruby
config.store_datetime_as_string = true
config.store_date_as_string     = true
```

### config.store_boolean_as_native

* *Default:* `true`
* *Type:* `Boolean`

By default, booleans are stored as native DynamoDB boolean attributes. When set to `false`, they are stored as single-character strings (`'t'` or `'f'`) for backward compatibility with legacy tables:

```ruby
config.store_boolean_as_native = false
```

### config.store_binary_as_native

* *Default:* `false`
* *Type:* `Boolean`

By default, binary data is stored as a Base64-encoded string. When set to `true`, binary fields persist as native DynamoDB binary attributes:

```ruby
config.store_binary_as_native = true
```

### config.store_empty_string_as_nil and config.store_attribute_with_nil_value

* *Default:* `store_empty_string_as_nil = true`, `store_attribute_with_nil_value = false`
* *Type:* `Boolean`

Controls how empty strings and `nil` attributes are persisted in DynamoDB.

When `config.store_empty_string_as_nil` is `true`, empty strings (`""`) are converted to `nil` before saving (a default preserved for compatibility with early DynamoDB versions that prohibited empty strings). Set to `false` to store empty strings as regular strings:

```ruby
config.store_empty_string_as_nil = false
```

When `config.store_attribute_with_nil_value` is `false`, attributes assigned `nil` are deleted from the DynamoDB item, saving storage space. When `true`, Dynamoid persists an explicit null value:

```ruby
config.store_attribute_with_nil_value = true
```

### config.convert_big_decimal

* *Default:* `false`
* *Type:* `Boolean`

By default, numbers inside `:map` and `:raw` fields are loaded as `BigDecimal` instances. When `config.convert_big_decimal` is `true`, Dynamoid converts them to `Float` values instead.

```ruby
config.convert_big_decimal = true
```

### config.use_yaml_unsafe_load and config.yaml_permitted_classes

* *Default:* `use_yaml_unsafe_load = false` (on Ruby >= 3.1), `yaml_permitted_classes = [Symbol, Set, Date, Time, DateTime]`
* *Type:* `Boolean` and `Array<Class>`

By default, Dynamoid deserializes `:serialized` fields safely using `YAML.safe_load`, allowing only the classes listed in `yaml_permitted_classes`. To permit additional classes, add them to `config.yaml_permitted_classes`:

```ruby
config.yaml_permitted_classes += [CustomClass]
```

If you trust the stored data or need to deserialize arbitrary Ruby classes without maintaining an allowlist, set `config.use_yaml_unsafe_load = true`.

For more details, see [YAML Deserialization](modeling_and_schema/fields_and_data_types.md#yaml-deserialization).

## Diagnostics & Logging

Dynamoid logs database operations, execution timings, and warnings. The configured logger is also forwarded directly to the underlying [`Aws::DynamoDB::Client`](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#initialize-instance_method). In Rails applications, Dynamoid defaults to `Rails.logger`. In standalone Ruby applications, it prints to `$stdout`.

### config.logger

* *Default:* `Rails.logger` in Rails; `Logger.new($stdout)` in standalone Ruby applications
* *Type:* `Logger` instance, `false`, or `nil`

Sets the active logger:

```ruby
config.logger = Logger.new('log/dynamoid.log')
```

To disable logging entirely (for example, in tests), pass `false` or `nil`:

```ruby
config.logger = false
```

Set the logger's level to `Logger::DEBUG` to output timing and argument details for every database operation:

```ruby
config.logger.level = Logger::DEBUG
```

### config.log_formatter

* *Default:* `nil`
* *Type:* `Aws::Log::Formatter` or `nil`

Customizes the log format used by the underlying AWS SDK client when logging HTTP request and response metadata:

```ruby
config.log_formatter = Aws::Log::Formatter.colored
```

You can pass built-in formatters such as `Aws::Log::Formatter.colored` or `Aws::Log::Formatter.short`, define custom pattern strings with `Aws::Log::Formatter.new(pattern)`, or provide any object responding to `#format(response)`. For available patterns, see the [AWS SDK Log Formatter documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Log/Formatter.html).

When left as `nil`, the AWS SDK uses its default format.

## Identity Map

Dynamoid includes an implementation of Fowler's *Identity Map* pattern, which ensures that each DynamoDB item is loaded into memory only once per context.

### config.identity_map

* *Default:* `false`
* *Type:* `Boolean`

When enabled, subsequent lookups for the same primary key return the existing in-memory model instance rather than issuing another request to DynamoDB:

```ruby
config.identity_map = true
```

Because the identity map retains object references in memory, enabling it without request-scoped clearing causes memory leaks in long-running processes (such as Puma servers or background workers) and can serve stale attributes across separate web requests.

In Ruby on Rails applications, insert the `Dynamoid::Middleware::IdentityMap` middleware in `config/application.rb` to clear the map at the beginning and end of each HTTP request:

```ruby
config.middleware.use Dynamoid::Middleware::IdentityMap
```

In other Rack applications, add the middleware in `config.ru`:

```ruby
use Dynamoid::Middleware::IdentityMap
```

In background job processors (such as Sidekiq or GoodJob), reset the map between jobs:

```ruby
Dynamoid::IdentityMap.clear
```

{{#include _includes/feedback.md}}
