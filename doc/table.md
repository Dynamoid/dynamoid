### Table

Dynamoid has some sensible defaults for you when you create a new table,
including the table name and the primary key column. But you can change
those if you like on table creation.

```ruby
class User
  include Dynamoid::Document

  table name: :awesome_users, key: :user_id, read_capacity: 5, write_capacity: 5
end
```

These fields will not change an existing table: so specifying a new
read_capacity and write_capacity here only works correctly for entirely
new tables. Similarly, while Dynamoid will look for a table named
`awesome_users` in your namespace, it won't change any existing tables
to use that name; and if it does find a table with the correct name, it
won't change its hash key, which it expects will be `user_id`. If this
table doesn't exist yet, however, Dynamoid will create it with these
options.

There is basic support for DynamoDB's [Time To Live (TTL)
mechanism](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html).
If you declare a field as a TTL field - it will be initialized if it doesn't
have a value yet. Default value is current time + specified seconds.

```ruby
class User
  include Dynamoid::Document

  table expires: { field: :ttl, after: 60 }

  field :ttl, :integer
end
```

Field used to store expiration time (e.g. `ttl`) should be declared
explicitly and should have numeric type (`integer`, `number`) only.
`datetime` type is also possible but only if it's stored as number
(there is a way to store time as a string also).

It's also possible to override a global option `Dynamoid::Config.timestamps`
on a table level:

```ruby
table timestamps: false
```

This option controls generation of timestamp fields
`created_at`/`updated_at`.

It's also possible to override table capacity mode configured globally
with table level option `capacity_mode`. Valid values are
`:provisioned`, `:on_demand` and `nil`:

```ruby
table capacity_mode: :on_demand
```

If table capacity mode is on-demand, another related table-level options
`read_capacity` and `write_capacity` will be ignored.
