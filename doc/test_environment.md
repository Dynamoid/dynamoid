## Test Environment

In test environment you will most likely want to clean the database
between test runs to keep tests completely isolated. This can be
achieved like so

```ruby
module DynamoidReset
  def self.all
    Dynamoid.adapter.list_tables.each do |table|
      # Only delete tables in our namespace
      if table =~ /^#{Dynamoid::Config.namespace}/
        Dynamoid.adapter.delete_table(table)
      end
    end
    Dynamoid.adapter.tables.clear
    # Recreate all tables to avoid unexpected errors
    Dynamoid.included_models.each { |m| m.create_table(sync: true) }
  end
end

# Reduce noise in test output
Dynamoid.logger.level = Logger::FATAL
```

If you're using RSpec you can invoke the above like so:

```ruby
RSpec.configure do |config|
  config.before(:each) do
    DynamoidReset.all
  end
end
```

In addition, the first test for each model may fail if the relevant models are not included in `included_models`. This can be fixed by adding this line before the `DynamoidReset` module:
```ruby
Dir[File.join(Dynamoid::Config.models_dir, '**/*.rb')].sort.each { |file| require file }
```
Note that this will require _all_ models in your models folder - you can also explicitly require only certain models if you would prefer to.

In Rails, you may also want to ensure you do not delete non-test data
accidentally by adding the following to your test environment setup:

```ruby
raise "Tests should be run in 'test' environment only" if Rails.env != 'test'

Dynamoid.configure do |config|
  config.namespace = "#{Rails.application.railtie_name}_#{Rails.env}"
end
```
