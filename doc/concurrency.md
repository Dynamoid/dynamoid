# Concurrency

Dynamoid supports basic, ActiveRecord-like optimistic locking on save
operations. Simply add a `lock_version` column to your table like so:

```ruby
class MyTable
  # ...

  field :lock_version, :integer

  # ...
end
```

In this example, all saves to `MyTable` will raise an
`Dynamoid::Errors::StaleObjectError` if a concurrent process loaded,
edited, and saved the same row. Your code should trap this exception,
reload the row (so that it will pick up the newest values), and try the
save again.

Calls to `update` and `update!` also increment the `lock_version`,
however, they do not check the existing value. This guarantees that a
update operation will raise an exception in a concurrent save operation,
however, a save operation will never cause an update to fail. Thus,
`update` is useful & safe only for doing atomic operations (e.g.
increment a value, add/remove from a set, etc), but should not be used
in a read-modify-write pattern.
