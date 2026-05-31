# Object Creation

Dynamoid's syntax is generally very similar to ActiveRecord's. Making
new objects is simple:

```ruby
u = User.new(name: 'Josh')
u.email = 'josh@joshsymonds.com'
u.save
```

Save forces persistence to the data store: a unique ID is also assigned,
but it is a string and not an auto-incrementing number.

```ruby
u.id # => '3a9f7216-4726-4aea-9fbc-8554ae9292cb'
```

To use associations, you use association methods very similar to
ActiveRecord's:

```ruby
address = u.addresses.create
address.city = 'Chicago'
address.save
```

To create multiple documents at once:

```ruby
User.create([{ name: 'Josh' }, { name: 'Nick' }])
```

There is an efficient and low-level way to create multiple documents
(without validation and callbacks running):

```ruby
users = User.import([{ name: 'Josh' }, { name: 'Nick' }])
```
