### PartiQL

To run PartiQL statements `Dynamoid.adapter.execute` method should be
used:

```ruby
Dynamoid.adapter.execute("UPDATE users SET name = 'Mike' WHERE id = '1'")
```

Parameters are also supported:

```ruby
Dynamoid.adapter.execute('SELECT * FROM users WHERE id = ?', ['1'])
```
