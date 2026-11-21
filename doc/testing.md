# Testing

Running automated tests with Dynamoid requires a deliberate testing strategy across several fronts: selecting an execution environment—such as a local emulator or a dedicated AWS sandbox account—preventing accidental data loss in remote environments, tuning configuration for local execution speed, and managing table lifecycles without database transactions.

## Configuration

When running tests against a local emulator (such as DynamoDB Local or LocalStack), configure Dynamoid in `config/environments/test.rb` or `spec/support/dynamoid.rb` to target the local endpoint and tune settings for test execution:

```ruby
Dynamoid.configure do |config|
  config.endpoint = ENV.fetch('DYNAMODB_ENDPOINT', 'http://localhost:8000')

  worker_id = ENV['TEST_ENV_NUMBER'] || Process.pid
  config.namespace = "myapp_test_#{worker_id}"

  config.sync_retry_wait_seconds = 0
  config.sync_retry_max_times = 5

  config.logger = false
  config.error_on_scan = true
end
```

Because local emulators create tables immediately, setting `sync_retry_wait_seconds = 0` eliminates the default 2-second polling delay. Suffixing `config.namespace` with `ENV['TEST_ENV_NUMBER']` isolates tables across parallel test workers (such as `parallel_tests`), and `config.error_on_scan = true` fails fast if a query accidentally falls back to a full-table scan.

## Safety Guards

To prevent test runs from accidentally modifying staging or production tables, add a guard in your test helper (`spec/support/dynamoid.rb` or `test/test_helper.rb`) to verify that the suite is running in the `test` environment:

```ruby
env = ENV['APP_ENV'] || ENV['RACK_ENV'] || (Rails.env if defined?(Rails))
raise 'Tests must run strictly in the test environment!' unless env == 'test'
```

When your test suite runs against a local emulator, also verify that `Dynamoid.config.endpoint` points to a local address rather than remote AWS:

```ruby
unless Dynamoid.config.endpoint&.start_with?('http://localhost', 'http://127.0.0.1', 'http://localstack')
  raise 'Expected Dynamoid to point to a local emulator, but found a remote endpoint!'
end
```

## Test Suite Integration

Because DynamoDB does not support rollbackable transactions, test suites cannot isolate test cases by rolling back database state. Instead, test isolation requires managing table lifecycles and clearing stored items between test runs. Dynamoid provides `Dynamoid::TestHelper` to manage provisioning, truncation, and resets.

To provision missing tables once before the test suite starts (or only for specific models when running a subset of tests), call `create_tables`:

```ruby
Dynamoid::TestHelper.create_tables
Dynamoid::TestHelper.create_tables(User, Post)
```

To clear stored items between individual tests while keeping the tables intact, call `truncate_tables`:

```ruby
Dynamoid::TestHelper.truncate_tables
Dynamoid::TestHelper.truncate_tables(User, Post)
```

Because `create_tables` skips tables that already exist, changing a model's primary key or secondary indexes requires dropping existing tables first. To delete all tables in the configured `config.namespace`, call `drop_tables`:

```ruby
Dynamoid::TestHelper.drop_tables
```

### RSpec

In projects using RSpec, configure table lifecycle hooks in `spec/support/dynamoid.rb` (or `spec/spec_helper.rb`):

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    Dynamoid::TestHelper.drop_tables
    Dynamoid::TestHelper.create_tables
  end

  config.before(:each) do
    Dynamoid::TestHelper.truncate_tables
  end
end
```

### Minitest

In projects using Minitest, add the equivalent lifecycle hooks to `test/test_helper.rb`:

```ruby
Dynamoid::TestHelper.drop_tables
Dynamoid::TestHelper.create_tables

class Minitest::Test
  def setup
    super
    Dynamoid::TestHelper.truncate_tables
  end
end
```

In Rails applications using `ActiveSupport::TestCase`, use the declarative `setup` block instead:

```ruby
class ActiveSupport::TestCase
  setup do
    Dynamoid::TestHelper.truncate_tables
  end
end
```

{{#include _includes/feedback.md}}
