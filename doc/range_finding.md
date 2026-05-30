### Range Finding

If you have a range index, Dynamoid provides a number of additional
other convenience methods to make your life a little easier:

```ruby
User.where('created_at.gt': DateTime.now - 1.day).all
User.where('created_at.lt': DateTime.now - 1.day).all
```

It also supports `gte` and `lte`. Turning those into symbols and
allowing a Rails SQL-style string syntax is in the works. You can only
have one range argument per query, because of DynamoDB inherent
limitations, so use it sensibly!
