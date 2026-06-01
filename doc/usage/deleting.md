# Deleting

In order to delete some items `delete_all` method should be used. Any
callback won't be called. Items delete in efficient way in batch.

```ruby
Address.where(city: 'London').delete_all
```
