### Querying

Querying can be done in one of the following ways:

```ruby
Address.find(address.id)              # Find directly by ID.
Address.where(city: 'Chicago').all    # Find by any number of matching criteria...
                                      # Though presently only "where" is supported.
Address.find_by_city('Chicago')       # The same as above, but using ActiveRecord's older syntax.
```

There is also a way to `#where` with a condition expression:

```ruby
Address.where('city = :c', c: 'Chicago')
```

A condition expression may contain operators (e.g. `<`, `>=`, `<>`),
keywords (e.g. `AND`, `OR`, `BETWEEN`) and built-in functions (e.g.
`begins_with`, `contains`) (see [documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.OperatorsAndFunctions.html)
for full syntax description).

**Warning:** Values (specified for a String condition expression) are
sent as-is, so Dynamoid field types that aren't supported natively by
DynamoDB (e.g. `datetime` and `date`) require explicit casting.

**Warning:** String condition expressions will be used by DynamoDB only
during filtering, so conditions on key attributes should be specified as a
Hash to perform a Query operation instead of a Scan. Don't use key
attributes in `#where`'s String condition expressions.

And you can also query on associations:

```ruby
u.addresses.where(city: 'Chicago').all
```

But keep in mind that DynamoDB — and document-based storage systems in
general — are not drop-in replacements for existing relational
databases. The above query does not efficiently perform a conditional
join, but instead finds all the user's addresses and naively filters
them in Ruby. For large associations, this is a performance hit compared
to relational database engines.

**Warning:** There is a caveat with filtering documents by `nil` value
attribute. By default, Dynamoid ignores attributes with a `nil` value and
doesn't store them in a DynamoDB document. This behavior could be
changed with the `store_attribute_with_nil_value` config option.

If Dynamoid ignores `nil` value attributes, `null`/`not_null` operators
should be used in the query:

```ruby
Address.where('postcode.null': true)
Address.where('postcode.not_null': true)
```

If Dynamoid keeps `nil` value attributes, `eq`/`ne` operators should be
used instead:

```ruby
Address.where(postcode: nil)
Address.where('postcode.ne': nil)
```

#### Limits

There are three types of limits that you can query with:

1. `record_limit` - The number of evaluated records that are returned by
   the query.
2. `scan_limit` - The number of scanned records that DynamoDB will look
   at before returning.
3. `batch_size` - The number of records requested from DynamoDB per
   underlying request, good for large queries!

Using these in various combinations results in the underlying requests
to be made in the smallest size possible and the query returns once
`record_limit` or `scan_limit` is satisfied. It will attempt to batch
whenever possible.

You can thus limit the number of evaluated records, or select a record
from which to start in order to support pagination.

```ruby
Address.record_limit(5).start(address) # Only 5 addresses starting at `address`
```
Where `address` is an instance of the model or a hash
`{the_model_hash_key: 'value', the_model_range_key: 'value'}`. Keep in
mind that if you are passing a hash to `.start()` you need to explicitly
define all required keys in it including range keys, depending on table
or secondary index signatures, otherwise you'll get an
`Aws::DynamoDB::Errors::ValidationException` either for `Exclusive Start
Key must have same size as table's key schema` or `The provided starting
key is invalid`

If you are potentially running over a large data set and this is
especially true when using certain filters, you may want to consider
limiting the number of scanned records (the number of records DynamoDB
infrastructure looks through when evaluating data to return):

```ruby
Address.scan_limit(5).start(address) # Only scan at most 5 records and return what's found starting from `address`
```

For large queries that return many rows, Dynamoid can use AWS' support
for requesting documents in batches:

```ruby
# Do some maintenance on the entire table without flooding DynamoDB
Address.batch(100).each { |addr| addr.do_some_work && sleep(0.01) }
Address.record_limit(10_000).batch(100).each { |addr| addr.do_some_work && sleep(0.01) } # Batch specified as part of a chain
```

The implication of batches is that the underlying requests are done in
the batch sizes to make the request and responses more manageable. Note
that this batching is for `Query` and `Scans` and not `BatchGetItem`
commands.

#### DynamoDB pagination

At times it can be useful to rely on DynamoDB [low-level
pagination](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html#Query.Pagination)
instead of fixed page sizes. Each page results in a single Query or
Scan call to DynamoDB, but returns an unknown number of records.

Access to the native DynamoDB pages can be obtained via the
`find_by_pages` method, which yields arrays of records.

```ruby
Address.find_by_pages do |addresses, metadata|
end
```

Each yielded page returns page metadata as the second argument, which
is a hash including a key `:last_evaluated_key`. The value of this key
can be used for the `start` method to fetch the next page of records.

This way it can be used, for instance, to implement pagination
efficiently in web applications:

```ruby
class UserController < ApplicationController
  def index
    next_page = params[:next_page_token] ? JSON.parse(Base64.decode64(params[:next_page_token])) : nil

    records, metadata = User.start(next_page).find_by_pages.first

    render json: {
      records: records,
      next_page_token: Base64.encode64(metadata[:last_evaluated_key].to_json)
    }
  end
end
```

#### Sort Conditions and Filters

You are able to optimize queries with conditions for sort keys. Following
operators are available: `gt`, `lt`, `gte`, `lte`, `begins_with`,
`between` as well as equality:

```ruby
Address.where(latitude: 10_212)
Address.where('latitude.gt': 10_212)
Address.where('latitude.lt': 10_212)
Address.where('latitude.gte': 10_212)
Address.where('latitude.lte': 10_212)
Address.where('city.begins_with': 'Lon')
Address.where('latitude.between': [10_212, 20_000])
```

You are able to filter results on the DynamoDB side and specify
conditions for non-key fields. Following additional operators are
available: `in`, `contains`, `not_contains`, `null`, `not_null`:

```ruby
Address.where('city.in': %w[London Edinburgh Birmingham])
Address.where('city.contains': ['on'])
Address.where('city.not_contains': ['ing'])
Address.where('postcode.null': false)
Address.where('postcode.not_null': true)
```

**WARNING:** Please take into account that `NULL` and `NOT_NULL`
operators check attribute presence in a document, not value. So if
attribute `postcode`'s value is `NULL`, `NULL` operator will return
false because attribute exists even if has `NULL` value.

#### Selecting some specific fields only

It could be done with `project` method:

```ruby
class User
  include Dynamoid::Document

  field :name
end

User.create(name: 'Alex')
user = User.project(:name).first

user.id         # => nil
user.name       # => 'Alex'
user.created_at # => nil
```

Returned models with have filled specified fields only.

Several fields could be specified:

```ruby
user = User.project(:name, :created_at)
```
