# Configuration & Runtime

Dynamoid provides extensive configuration options for AWS credentials, table defaults, retry/backoff policies, connection pooling, and logging.

Configuration is typically defined in an initializer (e.g., `config/initializers/dynamoid.rb` in Rails applications) using the `Dynamoid.configure` block:

```ruby
require 'dynamoid'

Dynamoid.configure do |config|
  # Table namespacing
  config.namespace = "myapp_#{Rails.env}"

  # AWS credentials and region
  config.access_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.region     = ENV['AWS_REGION'] || 'us-west-2'
end
```

## AWS Configuration & Credentials

### 1. Global AWS Configuration vs. Dynamoid-Specific Credentials

If your project already uses the AWS SDK for Ruby, you can configure AWS globally:

```ruby
Aws.config.update(
  region: 'us-west-2',
  credentials: Aws::Credentials.new(ENV.fetch('AWS_ACCESS_KEY_ID', nil), ENV.fetch('AWS_SECRET_ACCESS_KEY', nil))
)
```

Alternatively, if you want AWS credentials to apply exclusively to Dynamoid without overriding global AWS settings, configure them directly inside `Dynamoid.configure`:

```ruby
Dynamoid.configure do |config|
  config.access_key = ENV.fetch('DYNAMODB_ACCESS_KEY_ID', nil)
  config.secret_key = ENV.fetch('DYNAMODB_SECRET_ACCESS_KEY', nil)
  config.region     = 'us-west-2'
end
```

### 2. IAM Roles & Pre-Configured Credentials

To authenticate using IAM roles, AWS STS assume-role, or external credential providers, assign the credentials object directly to `config.credentials`:

```ruby
credentials = Aws::AssumeRoleCredentials.new(
  client: Aws::STS::Client.new(region: 'us-west-2'),
  role_arn: 'arn:aws:iam::123456789012:role/DynamoDBAppRole',
  role_session_name: 'dynamoid-session'
)

Dynamoid.configure do |config|
  config.region = 'us-west-2'
  config.credentials = credentials
end
```

### 3. Local DynamoDB Endpoint (Development & Testing)

To connect to a local DynamoDB instance (such as [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html) or LocalStack), specify `endpoint`:

```ruby
Dynamoid.configure do |config|
  config.endpoint = 'http://localhost:8000'
end
```

## Table Namespaces and Environment Isolation

Because DynamoDB table names are global within each AWS account and region, any two models that resolve to the same table name will access the same physical DynamoDB table.

The `config.namespace` setting prepends a prefix to all table names (joined by an underscore, such as `<namespace>_<table_name>`). How you configure this setting depends directly on your AWS account topology and deployment architecture.

### 1. Shared AWS Account Across Multiple Environments

When multiple application environments (such as `production`, `staging`, `pre-production`, and `qa`) share a single AWS account, configuring a namespace is essential to isolate data and prevent accidental overwrites:

```ruby
Dynamoid.configure do |config|
  config.namespace = "myapp_#{Rails.env}"
end
```

In Rails applications, Dynamoid automatically configures a default namespace: `dynamoid_<app_name>_#{Rails.env}` (for example, `dynamoid_my_app_development`).

### 2. Dedicated AWS Accounts per Environment

When following the AWS best practice of maintaining separate, dedicated AWS accounts for each environment (for example, separate AWS accounts for production, staging, and development):

* Tables in the production account belong strictly to production; tables in the staging account belong strictly to staging.
* In this architecture, environment prefixes in table names are often redundant. You can disable the namespace prefix by setting it to `nil`:

```ruby
Dynamoid.configure do |config|
  config.namespace = nil # Tables are named cleanly without prefixes: 'users', 'orders'
end
```

### 3. Multiple Applications Sharing an AWS Account

When multiple independent applications or microservices share a single AWS account, namespaces prevent table name collisions between services that define identically named models (such as a `User` model in both an authentication service and a billing service):

```ruby
# In the Billing application
Dynamoid.configure do |config|
  config.namespace = "billing_#{Rails.env}" # => 'billing_production_users'
end

# In the Auth application
Dynamoid.configure do |config|
  config.namespace = "auth_#{Rails.env}"    # => 'auth_production_users'
end
```

### 4. Shared Development Sandbox Accounts

When engineering teams share a single development AWS account or shared cloud sandbox, developers can isolate their personal tables by incorporating their username into the namespace:

```ruby
Dynamoid.configure do |config|
  developer = ENV['DEVELOPER_NAME'] || ENV['USER'] || 'dev'
  config.namespace = "myapp_#{developer}" # => 'myapp_alice_users'
end
```

This allows each engineer to create, populate, and reset tables during local development without interfering with other team members.

### 5. Automated Test Suites and Parallel CI

When running test suites against DynamoDB Local or a shared test AWS account, parallel test processes (such as `parallel_tests` or multiple CI runners) can dynamically set distinct namespaces:

```ruby
Dynamoid.configure do |config|
  worker_id = ENV['TEST_ENV_NUMBER'] || Process.pid
  config.namespace = "myapp_test_#{worker_id}"
end
```

Each test worker operates on its own set of isolated tables, preventing test race conditions.

### Namespace Precedence and Bypassing

* *Custom table names* — Specifying `table name: :custom_name` on a model still prepends the configured `config.namespace`.
* *ARNs* — Specifying `table arn: 'arn:aws:dynamodb:...'` ([Amazon Resource Name](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html)) bypasses `config.namespace` entirely. This is ideal when referencing a shared, centrally managed table in another AWS account or region.

## Retry & Backoff Strategies

When running batch operations (such as `.import` or `BatchGetItem`) or high-volume queries, DynamoDB may return unprocessed items if table throughput is exceeded. Dynamoid can automatically retry unprocessed items using a configurable backoff strategy.

### Built-in Strategies: Constant & Exponential

Dynamoid provides two built-in backoff strategies:

```ruby
# Constant delay: wait 2 seconds between retries
Dynamoid.configure do |config|
  config.backoff = { constant: 2.seconds }
end

# Truncated exponential backoff (recommended for production)
Dynamoid.configure do |config|
  config.backoff = { exponential: { base_backoff: 0.2.seconds, ceiling: 10 } }
end

# Use defaults for a strategy
Dynamoid.configure do |config|
  config.backoff = :exponential
end
```

### Custom Backoff Strategies

You can register a custom backoff generator:

```ruby
Dynamoid.configure do |config|
  config.backoff_strategies[:jitter] = lambda do |n|
    -> { sleep(rand(n)) }
  end

  config.backoff = { jitter: 5 }
end
```

## HTTP Connection & Timeouts

Dynamoid communicates with DynamoDB via HTTP requests. You can fine-tune HTTP timeouts and network proxies:

```ruby
Dynamoid.configure do |config|
  config.http_open_timeout     = 5   # Time to wait when opening a connection (seconds)
  config.http_read_timeout     = 15  # Time to wait for response data (seconds)
  config.http_idle_timeout     = 5   # Connection idle time before considered stale (seconds)
  config.http_continue_timeout = 1   # Wait for 100-continue response (seconds)
  config.http_proxy            = 'http://proxy.corp.example:8080' # Optional proxy
end
```

## Logging & Debugging

Dynamoid logs all database interactions through its logger. By default, it uses `Rails.logger` in Rails applications, or prints to `$stdout` in standalone Ruby apps.

To inspect raw DynamoDB HTTP requests, payloads, and execution timing, set the log level to `:debug`:

```ruby
Dynamoid.configure do |config|
  config.logger.level = Logger::DEBUG
end
```

Sample debug log output:
```text
D, [2026-10-01T12:00:00.840051 #75059] DEBUG -- : put_item | Request "{\"TableName\":\"myapp_users\",\"Item\":{...}}"
D, [2026-10-01T12:00:00.842397 #75059] DEBUG -- : (23.4 ms) PUT ITEM - ["myapp_users", {...}, {}]
```

### Formatting AWS SDK Logs

You can customize AWS SDK formatting using `log_formatter`:

```ruby
Dynamoid.configure do |config|
  config.log_formatter = Aws::Log::Formatter.colored
end
```

## Complete Configuration Reference

| Option | Type | Default | Description |
|---|---|---|---|
| `namespace` | `String` | `"dynamoid_#{app}_#{env}"` | Prefix prepended to all table names. Set to `nil` to disable. |
| `access_key` | `String` | `nil` | AWS access key ID. |
| `secret_key` | `String` | `nil` | AWS secret access key. |
| `credentials` | `Object` | `nil` | Pre-configured AWS credentials object (e.g. `Aws::AssumeRoleCredentials`). |
| `region` | `String` | `nil` | AWS region (e.g. `'us-west-2'`). |
| `endpoint` | `String` | `nil` | Custom endpoint URL (e.g. `'http://localhost:8000'`). |
| `capacity_mode` | `Symbol` | `:provisioned` | Default billing mode (`:provisioned` or `:on_demand`). |
| `read_capacity` | `Integer` | `100` | Default Read Capacity Units for new tables. |
| `write_capacity` | `Integer` | `20` | Default Write Capacity Units for new tables. |
| `warn_on_scan` | `Boolean` | `true` | Log a warning whenever a full-table Scan is performed. |
| `error_on_scan` | `Boolean` | `false` | Raise `Dynamoid::Errors::ScanError` when a Scan is performed. |
| `timestamps` | `Boolean` | `true` | Automatically manage `created_at` and `updated_at`. |
| `create_table_on_save` | `Boolean` | `true` | Automatically create the table in DynamoDB if missing on save. |
| `models_dir` | `String` | `'./app/models'` | Directory where model classes are located (used by Rake tasks). |
| `batch_size` | `Integer` | `100` | Chunk size when loading items via `BatchGetItem`. |
| `backoff` | `Hash, Symbol`| `nil` | Active retry/backoff strategy (`:constant`, `:exponential`). |
| `application_timezone`| `Symbol, String` | `:utc` | Timezone to convert `datetime` fields to on load. |
| `store_datetime_as_string` | `Boolean` | `false` | Store `datetime` attributes as ISO-8601 strings. |
| `store_date_as_string` | `Boolean` | `false` | Store `date` attributes as ISO-8601 strings. |
| `store_boolean_as_native` | `Boolean` | `true` | Store booleans as native DynamoDB booleans (`BOOL`). |
| `store_binary_as_native` | `Boolean` | `false` | Store binaries as native DynamoDB binary attributes (`B`). |
| `store_attribute_with_nil_value` | `Boolean` | `false` | Preserve `nil` attributes in DynamoDB items instead of omitting them. |
| `logger` | `Logger` | `Rails.logger` or stdout | Logger instance. |
