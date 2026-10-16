# Rake Tasks & Testing

Dynamoid provides built-in Rake tasks for managing DynamoDB tables and offers straightforward recipes for setting up clean, fast test suites with DynamoDB Local.

---

## Rake Tasks

Dynamoid includes several tasks for database provisioning and connectivity checks:

* `rake dynamoid:create_tables` - Scans your model directory (`config.models_dir`, `app/models` by default), loads all models, and creates any missing tables along with their declared secondary indexes (skipping tables that already exist).
* `rake dynamoid:ping` - Verifies network connectivity and authentication with DynamoDB.

### Using Rake Tasks in Standalone Applications

In non-Rails Ruby projects, require Dynamoid tasks in your `Rakefile`:

```ruby
# Rakefile
Rake::Task.define_task(:environment)
require 'dynamoid/tasks'
```

Ensure the `:environment` prerequisite task initializes Dynamoid configuration before the tasks execute.

---

## Testing Environment

Because DynamoDB is a cloud service, running automated test suites against AWS is slow, costly, and requires internet connectivity. Instead, test suites typically run against a local DynamoDB instance.

### 1. Setting Up DynamoDB Local

You can run [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html) via Docker:

```shell
docker run -p 8000:8000 amazon/dynamodb-local
```

Then configure Dynamoid to connect to the local endpoint in your test environment:

```ruby
# config/environments/test.rb or spec/spec_helper.rb
Dynamoid.configure do |config|
  config.endpoint  = 'http://localhost:8000'
  config.namespace = 'myapp_test'
end
```

### 2. Guarding Non-Test Environments

To prevent accidental data loss in production or staging, verify that test cleanup scripts run strictly in the test environment:

```ruby
raise "Tests must be run in the 'test' environment only!" if Rails.env != 'test'

```

### 3. Resetting Tables Between Tests

To ensure complete test isolation, reset tables between test runs. A common and efficient strategy is to delete and recreate tables within your test namespace:

```ruby
module DynamoidReset
  def self.all
    # Ensure all models are loaded so Dynamoid knows about all tables
    Dir[File.join(Dynamoid::Config.models_dir, '**/*.rb')].sort.each { |f| require f }

    # Delete all tables belonging to the test namespace
    Dynamoid.adapter.list_tables.each do |table|
      if table =~ /^#{Dynamoid::Config.namespace}/
        Dynamoid.adapter.delete_table(table)
      end
    end

    Dynamoid.adapter.tables.clear

    # Recreate tables synchronously
    Dynamoid.included_models.each { |m| m.create_table(sync: true) }
  end
end

# Suppress debug logs during test runs
Dynamoid.logger.level = Logger::FATAL
```

### 4. RSpec Integration

In `spec/spec_helper.rb` or `spec/rails_helper.rb`, invoke the reset hook:

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    DynamoidReset.all
  end

  config.before(:each) do
    # For speed, you can either clear items from tables or invoke DynamoidReset.all
    DynamoidReset.all
  end
end
```
