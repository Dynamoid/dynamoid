### Consistent Reads

Querying supports consistent reading. By default, DynamoDB reads are
eventually consistent: if you do a write and then a read immediately
afterwards, the results of the previous write may not be reflected. If
you need to do a consistent read (that is, you need to read the results
of a write immediately) you can do so, but keep in mind that consistent
reads are twice as expensive as regular reads for DynamoDB.

```ruby
Address.find(address.id, consistent_read: true)  # Find an address, ensure the read is consistent.
Address.where(city: 'Chicago').consistent.all    # Find all addresses where the city is Chicago, with a consistent read.
```
