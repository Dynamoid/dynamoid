### Backoff strategies


You can use several methods that run efficiently in batch mode like
`.find_all` and `.import`. It affects `Query` and `Scan` operations as
well.

The backoff strategy will be used when, for any reason, some items could
not be processed as part of a batch mode command. Operations will be
re-run to process these items.

Exponential backoff is the recommended way to handle throughput limits
exceeding and throttling on the table.

There are two built-in strategies - constant delay and truncated binary
exponential backoff. By default no backoff is used but you can specify
one of the built-in ones:

```ruby
Dynamoid.configure do |config|
  config.backoff = { constant: 2.second }
end

Dynamoid.configure do |config|
  config.backoff = { exponential: { base_backoff: 0.2.seconds, ceiling: 10 } }
end

```

You can specify the strategy without any arguments to use default
presets:

```ruby
Dynamoid.configure do |config|
  config.backoff = :constant
end
```

You can use your own strategy in the following way:

```ruby
Dynamoid.configure do |config|
  config.backoff_strategies[:custom] = lambda do |n|
    -> { sleep rand(n) }
  end

  config.backoff = { custom: 10 }
end
```
