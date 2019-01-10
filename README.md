# Dynamoid

You are viewing the README for version 3 of Dynamoid.  See the [CHANGELOG](https://github.com/Dynamoid/Dynamoid/blob/master/CHANGELOG.md#200) for details on breaking changes since 1.3.x.

For version 1.3.x use the [1-3-stable branch](https://github.com/Dynamoid/Dynamoid/blob/1-3-stable/README.md).

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It
provides similar functionality to ActiveRecord and improves on
Amazon's existing
[HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html)
by providing better searching tools and native association support.

DynamoDB is not like other document-based databases you might know, and is very different indeed from relational databases. It sacrifices anything beyond the simplest relational queries and transactional support to provide a fast, cost-efficient, and highly durable storage solution. If your database requires complicated relational queries and transaction support, then this modest Gem cannot provide them for you, and neither can DynamoDB. In those cases you would do better to look elsewhere for your database needs.

But if you want a fast, scalable, simple, easy-to-use database (and a Gem that supports it) then look no further!


| Project                 |  Dynamoid         |
|------------------------ | ----------------- |
| gem name                |  dynamoid         |
| license                 |  MIT              |
| download rank           |  [![Total Downloads](https://img.shields.io/gem/rt/Dynamoid.svg)](https://rubygems.org/gems/dynamoid) |
| version                 |  [![Gem Version](https://badge.fury.io/rb/dynamoid.svg)](https://badge.fury.io/rb/dynamoid) |
| dependencies            |  [![Depfu](https://badges.depfu.com/badges/6661c063c8e77a5008344fc7283a50aa/status.svg)](https://depfu.com) |
| code quality            |  [![Code Climate](https://codeclimate.com/github/Dynamoid/dynamoid.svg)](https://codeclimate.com/github/Dynamoid/dynamoid) |
| continuous integration  |  [![Build Status](https://travis-ci.org/Dynamoid/dynamoid.svg?branch=master)](https://travis-ci.org/Dynamoid/dynamoid) |
| test coverage           |  [![Coverage Status](https://coveralls.io/repos/github/Dynamoid/Dynamoid/badge.svg?branch=master)](https://coveralls.io/github/Dynamoid/Dynamoid?branch=master) |
| triage helpers          |  [![CodeTriage Helpers](https://www.codetriage.com/dynamoid/dynamoid/badges/users.svg)](https://www.codetriage.com/dynamoid/dynamoid) |
| homepage                |  [https://github.com/Dynamoid/dynamoid](https://github.com/Dynamoid/dynamoid) |
| documentation           |  [http://rdoc.info/github/Dynamoid/dynamoid/frames](http://rdoc.info/github/Dynamoid/dynamoid/frames) |

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your Gemfile:

```ruby
gem 'dynamoid'
```
## Prerequisities

Dynamoid depends on the aws-sdk, and this is tested on the current version of aws-sdk (~> 3), rails (>= 4).
Hence the configuration as needed for aws to work will be dealt with by aws setup.

### AWS SDK Version Compatibility

Make sure you are using the version for the right AWS SDK.

| Dynamoid version | AWS SDK Version |
| ---------------- | --------------- |
| 0.x              | 1.x             |
| 1.x              | 2.x             |
| 2.x              | 2.x             |
| 3.x              | 3.x             |

### AWS Configuration

Configure AWS access:
[Reference](https://github.com/aws/aws-sdk-ruby)

For example, to configure AWS access:

Create `config/initializers/aws.rb` as follows:

```ruby

  Aws.config.update({
    region: 'us-west-2',
    credentials: Aws::Credentials.new('REPLACE_WITH_ACCESS_KEY_ID', 'REPLACE_WITH_SECRET_ACCESS_KEY'),
  })

```

Alternatively, if you don't want Aws connection settings to be overwritten for you entire project, you can specify connection settings for Dynamoid only, by setting those in the `Dynamoid.configure` clause:

```ruby
  require 'dynamoid'
  Dynamoid.configure do |config|
    config.access_key = 'REPLACE_WITH_ACCESS_KEY_ID'
    config.secret_key = 'REPLACE_WITH_SECRET_ACCESS_KEY'
    config.region = 'us-west-2'
  end
```

For a full list of the DDB regions, you can go
[here](http://docs.aws.amazon.com/general/latest/gr/rande.html#ddb_region).

Then you need to initialize Dynamoid config to get it going. Put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

```ruby
  require 'dynamoid'
  Dynamoid.configure do |config|
    config.namespace = 'dynamoid_app_development' # To namespace tables created by Dynamoid from other tables you might have. Set to nil to avoid namespacing.
    config.endpoint = 'http://localhost:3000' # [Optional]. If provided, it communicates with the DB listening at the endpoint. This is useful for testing with [Amazon Local DB] (http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html).
  end
```

### Ruby & Rails Compatibility

Dynamoid supports Ruby >= 2.3 and Rails >= 4.2.

Its compatibility is tested in following way:

| Ruby / Active Record  | 4.2.x | 5.0.x | 5.1.x | 5.2.x |
|:---------------------:|:-----:|:-----:|:-----:|:-----:|
| 2.3.7                 | ✓     | ✓     | ✓     | ✓     |
| 2.4.4                 | ✓     | ✓     | ✓     | ✓     |
| 2.5.1                 | ✓     | ✓     | ✓     | ✓     |
| jruby-9.1.17.0        | ✓     | ✓     | ✓     | ✓     |

## Setup

You *must* include `Dynamoid::Document` in every Dynamoid model.

```ruby
class User
  include Dynamoid::Document

end
```

### Table

Dynamoid has some sensible defaults for you when you create a new table, including the table name and the primary key column. But you can change those if you like on table creation.

```ruby
class User
  include Dynamoid::Document

  table name: :awesome_users, key: :user_id, read_capacity: 5, write_capacity: 5
end
```

These fields will not change an existing table: so specifying a new read_capacity and write_capacity here only works correctly for entirely new tables. Similarly, while Dynamoid will look for a table named `awesome_users` in your namespace, it won't change any existing tables to use that name; and if it does find a table with the correct name, it won't change its hash key, which it expects will be `user_id`. If this table doesn't exist yet, however, Dynamoid will create it with these options.

### Fields

You'll have to define all the fields on the model and the data type of each field. Every field on the object must be included here; if you miss any they'll be completely bypassed during DynamoDB's initialization and will not appear on the model objects.

By default, fields are assumed to be of type `:string`. Other built-in types are
`:integer`, `:number`, `:set`, `:array`, `:datetime`, `date`, `:boolean`, `:raw` and `:serialized`.
`raw` type means you can store Ruby Array, Hash, String and numbers.
If built-in types do not suit you, you can use a custom field type represented by an arbitrary class, provided that the class supports a compatible serialization interface.
The primary use case for using a custom field type is to represent your business logic with high-level types, while ensuring portability or backward-compatibility of the serialized representation.

#### Note on boolean type

The boolean fields are stored as DynamoDB boolean values by default.
Dynamoid can store boolean values as strings as well - `'t'` and `'f'`.
So if you want to change default format of boolean field you can easily
achieve this with `store_as_native_boolean` field option:

```ruby
class Document
  include DynamoId::Document

  field :active, :boolean, store_as_native_boolean: false
end
```

#### Note on date type

By default date fields are persisted as days count since 1 January 1970 like UNIX time. If you prefer dates to be stored as ISO-8601 formatted strings instead then set `store_as_string` to `true`

```ruby
class Document
  include DynamoId::Document

  field :sent_on, :date, store_as_string: true
end
```

#### Note on datetime type

By default datetime fields are persisted as UNIX timestamps with millisecond precision in DynamoDB. If you prefer datetimes to be stored as ISO-8601 formatted strings instead then set `store_as_string` to `true`

```ruby
class Document
  include DynamoId::Document

  field :sent_at, :datetime, store_as_string: true
end
```

WARNING: Fields in numeric format are stored with nanoseconds as a fraction part and precision could be lost.
That's why `datetime` field in numeric format shouldn't be used as a range key.

You have two options if you need to use a `datetime` field as a range key:
* string format
* store `datetime` values without milliseconds e.g. cut them
  manually with `change` method - `Time.now.change(usec: 0)`

#### Note on set type

`Dynamoid`'s type `set` is stored as DynamoDB's Set attribute type.
DynamoDB supports only Set of strings, numbers and binary.
Moreover Set *must* contain elements of the same type only.

In order to use some other `Dynamoid`'s types you can specify `of` option
to declare the type of set elements.

As a result of that DynamoDB limitation, in Dynamoid only the following
scalar types are supported (note: does not support `boolean`):
`integer`, `number`, `date`, `datetime`, `serializable` and custom types.

```ruby
class Document
  include DynamoId::Document

  field :tags, :set, of: :integer
end
```

It's possible to specify field options like `store_as_string` for `datetime` field
or `serializer` for `serializable` field for `set` elements type:

```ruby
class Document
  include DynamoId::Document

  field :values, :set, of: { serialized: { serializer: JSON } }
  field :dates, :set, of: { date: { store_as_string: true } }
  field :datetimes, :set, of: { datetime: { store_as_string: false } }
end
```

DynamoDB doesn't allow empty strings in fields configured as `set`.
Abiding by this restriction, when `Dynamoid` saves a document it removes all empty strings in set fields.

#### Note on array type

`Dynamoid`'s type `array` is stored as DynamoDB's List attribute type.
It can contain elements of different types (in contrast to Set attribute type).

If you need to store in array field elements of `datetime`, `date`,
`serializable` or some custom type, which DynamoDB doesn't support
natively, you should specify element type with `of` option:

```ruby
class Document
  include DynamoId::Document

  field :dates, :array, of: :date
end
```

#### Magic Columns

You get magic columns of `id` (`string`), `created_at` (`datetime`), and `updated_at` (`datetime`) for free.

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :rank, :integer
  field :number, :number
  field :joined_at, :datetime
  field :hash, :serialized

end
```

#### Default Values

You can optionally set a default value on a field using either a plain value or a lambda:

```ruby
  field :actions_taken, :integer, default: 0
  field :joined_at, :datetime, default: -> { Time.now }
```

#### Custom Types

To use a custom type for a field, suppose you have a `Money` type.

```ruby
  class Money
    # ... your business logic ...

    def dynamoid_dump
      'serialized representation as a string'
    end

    def self.dynamoid_load(serialized_str)
      # parse serialized representation and return a Money instance
      Money.new(1.23)
    end
  end

  class User
    include Dynamoid::Document

    field :balance, Money
  end
```

If you want to use a third-party class (which does not support `#dynamoid_dump` and `.dynamoid_load`)
as your field type, you can use an adapter class providing `.dynamoid_dump` and `.dynamoid_load` class methods
for your third-party class.  (`.dynamoid_load` can remain the same from the previous example; here we just
add a level of indirection for serializing.)  Example:

```ruby
  # Third-party Money class
  class Money; end

  class MoneyAdapter
    def self.dynamoid_load(money_serialized_str)
      Money.new(1.23)
    end

    def self.dynamoid_dump(money_obj)
      money_obj.value.to_s
    end
  end

  class User
    include Dynamoid::Document

    field :balance, MoneyAdapter
  end
```

Lastly, you can control the data type of your custom-class-backed field at the DynamoDB level.
This is especially important if you want to use your custom field as a numeric range or for
number-oriented queries. By default custom fields are persisted as a string attribute, but
your custom class can override this with a `.dynamoid_field_type` class method, which would
return either `:string` or `:number`.

DynamoDB may support some other attribute types that are not yet supported by Dynamoid.

### Sort key

Along with partition key table may have a sort key. In order to declare it in a model
`range` class method should be used:

```ruby
class Post
  include Dynamoid::Document

  range :posted_at, :datetime
end
```

Second argument, type, is optional. Default type is `string`.

### Associations

Just like in ActiveRecord (or your other favorite ORM), Dynamoid uses associations to create links between models.

The only supported associations (so far) are `has_many`, `has_one`, `has_and_belongs_to_many`, and `belongs_to`. Associations are very simple to create: just specify the type, the name, and then any options you'd like to pass to the association. If there's an inverse association either inferred or specified directly, Dynamoid will update both objects to point at each other.

```ruby
class User
  include Dynamoid::Document

  # ...

  has_many :addresses
  has_many :students, class: User
  belongs_to :teacher, class_name: :user
  belongs_to :group
  belongs_to :group, foreign_key: :group_id
  has_one :role
  has_and_belongs_to_many :friends, inverse_of: :friending_users

end

class Address
  include Dynamoid::Document

  # ...

  belongs_to :user # Automatically links up with the user model

end
```

Contrary to what you'd expect, association information is always contained on the object specifying the association, even if it seems like the association has a foreign key. This is a side effect of DynamoDB's structure: it's very difficult to find foreign keys without an index. Usually you won't find this to be a problem, but it does mean that association methods that build new models will not work correctly -- for example, `user.addresses.new` returns an address that is not associated to the user. We'll be correcting this ~soon~ maybe someday, if we get a pull request.

### Validations

Dynamoid bakes in ActiveModel validations, just like ActiveRecord does.

```ruby
class User
  include Dynamoid::Document

  # ...

  validates_presence_of :name
  validates_format_of :email, with: /@/
end
```

To see more usage and examples of ActiveModel validations, check out the [ActiveModel validation documentation](http://api.rubyonrails.org/classes/ActiveModel/Validations.html).

If you want to bypass model validation, pass `validate: false` to `save` call:

```ruby
model.save(validate: false)
```

### Callbacks

Dynamoid also employs ActiveModel callbacks. Right now, callbacks are defined on ```save```, ```update```, ```destroy```, which allows you to do ```before_``` or ```after_``` any of those.

```ruby
class User
  include Dynamoid::Document

  # ...

  before_save :set_default_password
  after_create :notify_friends
  after_destroy :delete_addresses
end
```

### STI

Dynamoid supports STI (Single Table Inheritance) like Active Record does. You need just specify `type` field in a base class. Example:

```ruby
class Animal
  include Dynamoid::Document

  field :name
  field :type
end

class Cat < Animal
  field :lives, :integer
end

cat = Cat.create(name: 'Morgan')
animal = Animal.find(cat.id)
animal.class
#=>  Cat
```

If you already have DynamoDB tables and `type` field already exists and has its own semantic it leads to conflict.
It's possible to tell Dynamoid to use another field (even not existing)
instead of `type` one with `inheritance_field` table option:

```ruby
class Car
  include Dynamoid::Document
  table inheritance_field: :my_new_type

  field :my_new_type
end

c = Car.create
c.my_new_type
#=> "Car"
```

### Type casting

Dynamid supports type casting and tryes to do it in the most convinient way.
Values for all fields (except custom type) are coerced to declared field types.

Some obvious rules are used, e.g.:

for boolean field:
```ruby
document.boolean_field = 'off'
# => false
document.boolean_field = 'false'
# => false
document.boolean_field = 'some string'
# => true
```

or for integer field:
```ruby
document.integer_field = 42.3
# => 42
document.integer_field = '42.3'
# => 42
document.integer_field = true
# => 1
```

If time zone isn't specified for `datetime` value - application time zone is used.

To access field value before type casting following method could be
used: `attributes_before_type_cast` and `read_attribute_before_type_cast`.

There is `<name>_before_type_cast` method for every field in a model as well.

## Usage

### Object Creation

Dynamoid's syntax is generally very similar to ActiveRecord's. Making new objects is simple:

```ruby
u = User.new(name: 'Josh')
u.email = 'josh@joshsymonds.com'
u.save
```

Save forces persistence to the datastore: a unique ID is also assigned, but it is a string and not an auto-incrementing number.

```ruby
u.id # => '3a9f7216-4726-4aea-9fbc-8554ae9292cb'
```

To use associations, you use association methods very similar to ActiveRecord's:

```ruby
address = u.addresses.create
address.city = 'Chicago'
address.save
```

To create multiple documents at once:

```ruby
User.create([{name: 'Josh'}, {name: 'Nick'}])
```

There is an efficient and low-level way to create multiple documents
(without validation and callbacks running):

```ruby
users = User.import([{name: 'Josh'}, {name: 'Nick'}])
```

### Querying

Querying can be done in one of three ways:

```ruby
Address.find(address.id)              # Find directly by ID.
Address.where(city: 'Chicago').all    # Find by any number of matching criteria... though presently only "where" is supported.
Address.find_by_city('Chicago')       # The same as above, but using ActiveRecord's older syntax.
```

And you can also query on associations:

```ruby
u.addresses.where(city: 'Chicago').all
```

But keep in mind Dynamoid -- and document-based storage systems in general -- are not drop-in replacements for existing relational databases. The above query does not efficiently perform a conditional join, but instead finds all the user's addresses and naively filters them in Ruby. For large associations this is a performance hit compared to relational database engines.

#### Limits

There are three types of limits that you can query with:

1. `record_limit` - The number of evaluated records that are returned by the query.
2. `scan_limit` - The number of scanned records that DynamoDB will look at before returning.
3. `batch_size` - The number of records requested to DynamoDB per underlying request, good for large queries!

Using these in various combinations results in the underlying requests to be made in the smallest size possible and
the query returns once `record_limit` or `scan_limit` is satisfied. It will attempt to batch whenever possible.

You can thus limit the number of evaluated records, or select a record from which to start in order to support pagination.

```ruby
Address.record_limit(5).start(address) # Only 5 addresses starting at `address`
```
Where `address` is an instance of the model or a hash `{the_model_hash_key: 'value', the_model_range_key: 'value'}`:
Keep in mind that if you are passing a hash to `.start()` you need to explicitly define all required keys in it including range keys, depending on table or secondary indexes signatures, otherwise you'll get an `Aws::DynamoDB::Errors::ValidationException` either for `Exclusive Start Key must have same size as table's key schema` or `The provided starting key is invalid`

If you are potentially running over a large data set and this is especially true when using certain filters, you may
want to consider limiting the number of scanned records (the number of records DynamoDB infrastructure looks through
when evaluating data to return):

```ruby
Address.scan_limit(5).start(address) # Only scan at most 5 records and return what's found starting from `address`
```

For large queries that return many rows, Dynamoid can use AWS' support for requesting documents in batches:

```ruby
# Do some maintenance on the entire table without flooding DynamoDB
Address.all(batch_size: 100).each { |address| address.do_some_work; sleep(0.01) }
Address.record_limit(10_000).batch(100).each { … } # Batch specified as part of a chain
```

The implication of batches is that the underlying requests are done in the batch sizes to make the request and responses
more manageable. Note that this batching is for `Query` and `Scans` and not `BatchGetItem` commands.

#### Sort Conditions and Filters

You are able to optimize query with condition for sort key. Following operators are available: `gt`, `lt`, `gte`, `lte`,
`begins_with`, `between` as well as equality:

```ruby
Address.where(latitude: 10212)
Address.where('latitude.gt': 10212)
Address.where('latitude.lt': 10212)
Address.where('latitude.gte': 10212)
Address.where('latitude.lte': 10212)
Address.where('city.begins_with': 'Lon')
Address.where('latitude.between': [10212, 20000])
```

You are able to filter results on the DynamoDB side and specify conditions for non-key fields.
Following operators are available: `in`, `contains`, `not_contains`:

```ruby
Address.where('city.in': ['London', 'Edenburg', 'Birmingham'])
Address.where('city.contains': ['on'])
Address.where('city.not_contains': ['ing'])
```

### Consistent Reads

Querying supports consistent reading. By default, DynamoDB reads are eventually consistent: if you do a write and then a read immediately afterwards, the results of the previous write may not be reflected. If you need to do a consistent read (that is, you need to read the results of a write immediately) you can do so, but keep in mind that consistent reads are twice as expensive as regular reads for DynamoDB.

```ruby
Address.find(address.id, consistent_read: true)  # Find an address, ensure the read is consistent.
Address.where(city: 'Chicago').consistent.all    # Find all addresses where the city is Chicago, with a consistent read.
```

### Range Finding

If you have a range index, Dynamoid provides a number of additional other convenience methods to make your life a little easier:

```ruby
User.where("created_at.gt": DateTime.now - 1.day).all
User.where("created_at.lt": DateTime.now - 1.day).all
```

It also supports `gte` and `lte`. Turning those into symbols and allowing a Rails SQL-style string syntax is in the works. You can only have one range argument per query, because of DynamoDB's inherent limitations, so use it sensibly!


### Updating

In order to update document you can use high level methods
`#update_attributes`, `#update_attribute` and `.update`.
They run validation and collbacks.

```ruby
Address.find(id).update_attributes(city: 'Chicago')
Address.find(id).update_attribute(:city, 'Chicago')
Address.update(id, city: 'Chicago')
Address.update(id, { city: 'Chicago' }, if: { deliverable: true })
```

There are also some low level methods `#update`, `.update_fields` and
`.upsert`. They don't run validation and callbacks (except `#update` - it
runs `update` callbacks). All of them support conditional updates.
`#upsert` will create new document if document with specified `id`
doesn't exist.

```ruby
Adderess.find(id).update do |i|
  i.set city: 'Chicago'
  i.add latitude: 100
  i.delete set_of_numbers: 10
end
Adderess.find(id).update(if: { deliverable: true }) do |i|
  i.set city: 'Chicago'
end
Address.update_fields(id, city: 'Chicago')
Address.update_fields(id, { city: 'Chicago' }, if: { deliverable: true })
Address.upsert(id, city: 'Chicago')
Address.upsert(id, { city: 'Chicago' }, if: { deliverable: true })
```

### Deleting

In order to delete some items `delete_all` method should be used.
Any callback wont be called. Items delete in efficient way in batch.

```ruby
Address.where(city: 'London').delete_all
```

### Global Secondary Indexes

You can define index with `global_secondary_index`:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :age, :number

  global_secondary_index hash_key: :age # Must come after field definitions.
end
```

There are following options:
* `hash_key` - is used as hash key of an index,
* `range_key` - is used as range key of an index,
* `projected_attributes` - list of fields to store in an index or has a predefiled value `:keys_only`, `:all`; `:keys_only` is a default,
* `name` - an index will be created with this name when a table is created; by default name is generated and contains table name and keys names,
* `read_capacity` - is used when table creates and used as an index capacity; by default equals `Dynamoid::Config.read_capacity`,
* `write_capacity` - is used when table creates and used as an index capacity; by default equals `Dynamoid::Config.write_capacity`

The only mandatory option is `name`.

To use index in `Document.where` implicitly you need to project all the fields with option `projected_attributes: :all`.

There are two ways to query Global Secondary Indexes (GSI).

#### Explicit

The first way explicitly uses your GSI and utilizes the `find_all_by_secondary_index` method which will lookup a valid
GSI to use based on the inputs, you MUST provide the correct keys to match the GSI you want:

```ruby
find_all_by_secondary_index(
    {
        dynamo_primary_key_column_name => dynamo_primary_key_value
    }, # The signature of find_all_by_secondary_index is ugly, so must be an explicit hash here
    :range => {
        "#{range_column}.#{range_modifier}" => range_value
    },
    # false is the same as DESC in SQL (newest timestamp first)
    # true is the same as ASC in SQL (oldest timestamp first)
    scan_index_forward: false # or true
)
```

Where the range modifier is one of `Dynamoid::Finders::RANGE_MAP.keys`, where the `RANGE_MAP` is:

```ruby
RANGE_MAP = {
  'gt'            => :range_greater_than,
  'lt'            => :range_less_than,
  'gte'           => :range_gte,
  'lte'           => :range_lte,
  'begins_with'   => :range_begins_with,
  'between'       => :range_between,
  'eq'            => :range_eq
}
```

Most range searches, like `eq`, need a single value, and searches like `between`, need an array with two values.

#### Implicit

The second way implicitly uses your GSI through the `where` clauses and deduces the index based on the query fields
provided. Another added benefit is that it is built into query chaining so you can use all the methods used in normal
querying. The explicit way from above would be rewritten as follows:

```ruby
where(dynamo_primary_key_column_name => dynamo_primary_key_value,
      "#{range_column}.#{range_modifier}" => range_value)
  .scan_index_forward(false)
```

The only caveat with this method is that because it is also used for general querying, it WILL NOT use a GSI unless it
explicitly has defined `projected_attributes: :all` on the GSI in your model. This is because GSIs that do not have all
attributes projected will only contain the index keys and therefore will not return objects with fully resolved field
values. It currently opts to provide the complete results rather than partial results unless you've explicitly looked up
the data.

*Future TODO could involve implementing `select` in chaining as well as resolving the fields with a second query against
the table since a query against GSI then a query on base table is still likely faster than scan on the base table*

## Configuration

Listed below are all configuration options.

* `adapter` - usefull only for the gem developers to switch to a new adapter. Default and the only available value is `aws_sdk_v3`
* `namespace` - prefix for table names, default is `dynamoid_#{application_name}_#{environment}` for Rails application and `dynamoid` otherwise
* `logger` - by default it's a `Rails.logger` in Rails application and `stdout` otherwise. You can disable logging by setting `nil` or `false` values. Set `true` value to use defaults
* `access_key` - DynamoDb custom credentials for AWS, override global AWS credentials if they present
* `secret_key` - DynamoDb custom credentials for AWS, override global AWS credentials if they present
* `region` - DynamoDb custom credentials for AWS, override global AWS credentials if they present
* `batch_size` - when you try to load multiple items at once with `batch_get_item` call Dynamoid loads them not with one api call but piece by piece. Default is 100 items
* `read_capacity` - is used at table or indices creation. Default is 100 (units)
* `write_capacity` - is used at table or indices creation. Default is 20 (units)
* `warn_on_scan` - log warnings when scan table. Default is `true`
* `endpoint` - if provided, it communicates with the DynamoDB listening at the endpoint. This is useful for testing with [Amazon Local DB]
* `identity_map` - ensures that each object gets loaded only once by keeping every loaded object in a map. Looks up objects using the map when referring to them. Isn't thread safe. Default is `false`.
  `Use Dynamoid::Middleware::IdentityMap` to clear identity map for each HTTP request
* `timestamps` - by default Dynamoid sets `created_at` and `updated_at` fields for model at creation and updating. You can disable this behavior by setting `false` value
* `sync_retry_max_times` - when Dynamoid creates or deletes table synchronously it checks for completion specified times. Default is 60 (times). It's a bit over 2 minutes by default
* `sync_retry_wait_seconds` - time to wait between retries. Default is 2 (seconds)
* `convert_big_decimal` - if `true` then Dynamoid converts numbers stored in `Hash` in `raw` field to float. Default is `false`
* `models_dir` - `dynamoid:create_tables` rake task loads DynamoDb models from this directory. Default is `./app/models`.
* `application_timezone` - Dynamoid converts all `datetime` fields to specified time zone when loads data from the storage.
  Acceptable values - `:utc`, `:local` (to use system time zone) and time zone name e.g. `Eastern Time (US & Canada)`. Default is `utc`
* `dynamodb_timezone` - When a datetime field is stored in string format Dynamoid converts it to specified time zone when saves a value to the storage.
  Acceptable values - `:utc`, `:local` (to use system time zone) and time zone name e.g. `Eastern Time (US & Canada)`. Default is `utc`
* `store_datetime_as_string` - if `true` then Dynamoid stores :datetime fields in ISO 8601 string format. Default is `false`
* `store_date_as_string` - if `true` then Dynamoid stores :date fields in ISO 8601 string format. Default is `false`
* `store_boolean_as_native` - if `true` Dynamoid stores boolean fields as native DynamoDB
  boolean values. Otherwise boolean fields are stored as string values
`'t'` and `'f'`. Default is true
* `backoff` - is a hash: key is a backoff strategy (symbol), value is parameters for the strategy. Is used in batch operations. Default id `nil`
* `backoff_strategies`: is a hash and contains all available strategies. Default is { constant: ..., exponential: ...}


## Concurrency

Dynamoid supports basic, ActiveRecord-like optimistic locking on save operations. Simply add a `lock_version` column to your table like so:

```ruby
class MyTable
  # ...

  field :lock_version, :integer

  # ...
end
```

In this example, all saves to `MyTable` will raise an `Dynamoid::Errors::StaleObjectError` if a concurrent process loaded, edited, and saved the same row. Your code should trap this exception, reload the row (so that it will pick up the newest values), and try the save again.

Calls to `update` and `update!` also increment the `lock_version`, however they do not check the existing value. This guarantees that a update operation will raise an exception in a concurrent save operation, however a save operation will never cause an update to fail. Thus, `update` is useful & safe only for doing atomic operations (e.g. increment a value, add/remove from a set, etc), but should not be used in a read-modify-write pattern.


### Backoff strategies


You can use several methods that run efficiently in batch mode like `.find_all` and `.import`. It affects `Query` and `Scan` operations as well.

The backoff strategy will be used when, for any reason, some items could not be processed as part of a batch mode command.
Operations will be re-run to process these items.

Exponential backoff is the recommended way to handle throughput limits exceeding and throttling on the table.

There are two built-in strategies - constant delay and truncated binary exponential backoff.
By default no backoff is used but you can specify one of the built-in ones:

```ruby
Dynamoid.configure do |config|
  config.backoff = { constant: 2.second }
end

Dynamoid.configure do |config|
  config.backoff = { exponential: { base_backoff: 0.2.seconds, ceiling: 10 } }
end

```

You can just specify strategy without any arguments to use default presets:

```ruby
Dynamoid.configure do |config|
  config.backoff = :constant
end
```

You can use your own strategy in following way:

```ruby
Dynamoid.configure do |config|
  config.backoff_strategies[:custom] = lambda do |n|
    -> { sleep rand(n) }
  end

  config.backoff = { custom: 10 }
end
```


## Rake Tasks

  * `rake dynamoid:create_tables`
  * `rake dynamoid:ping`

## Test Environment

In test environment you will most likely want to clean the database between test runs to keep tests completely isolated. This can be achieved like so

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

In Rails, you may also want to ensure you do not delete non-test data accidentally by adding the following to your test environment setup:

```ruby
raise "Tests should be run in 'test' environment only" if Rails.env != 'test'
Dynamoid.configure do |config|
  config.namespace = "#{Rails.application.railtie_name}_#{Rails.env}"
end
```

## Credits

Dynamoid borrows code, structure, and even its name very liberally from the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without Mongoid to crib from none of this would have been possible, and I hope they don't mind me reusing their very awesome ideas to make DynamoDB just as accessible to the Ruby world as MongoDB.

Also, without contributors the project wouldn't be nearly as awesome. So many thanks to:

* [Logan Bowers](https://github.com/loganb)
* [Lane LaRue](https://github.com/luxx)
* [Craig Heneveld](https://github.com/cheneveld)
* [Anantha Kumaran](https://github.com/ananthakumaran)
* [Jason Dew](https://github.com/jasondew)
* [Luis Arias](https://github.com/luisantonioa)
* [Stefan Neculai](https://github.com/stefanneculai)
* [Philip White](https://github.com/philipmw) *
* [Peeyush Kumar](https://github.com/peeyush1234)
* [Sumanth Ravipati](https://github.com/sumocoder)
* [Pascal Corpet](https://github.com/pcorpet)
* [Brian Glusman](https://github.com/bglusman) *
* [Peter Boling](https://github.com/pboling) *
* [Andrew Konchin](https://github.com/andrykonchin) *

\* Current Maintainers

## Running the tests

Running the tests is fairly simple. You should have an instance of DynamoDB running locally. Follow these steps to setup your test environment.

 * First download and unpack the latest version of DynamoDB.  We have a script that will do this for you if you use homebrew on a Mac.

    ```shell
    bin/setup
    ```

 * Start the local instance of DynamoDB to listen in ***8000*** port

    ```shell
    bin/start_dynamodblocal
    ```

 * and lastly, use `rake` to run the tests.

    ```shell
    rake
    ```

 * When you are done, remember to stop the local test instance of dynamodb

    ```shell
    bin/stop_dynamodblocal
    ```

If you want to run all the specs that travis runs, use `bundle exec wwtd`, but first you will need to setup all the rubies, for each of `%w( 2.0.0-p648 2.1.10 2.2.6 2.3.3 2.4.1 jruby-9.1.8.0 )`.  When you run `bundle exec wwtd` it will take care of starting and stopping the local dynamodb instance.

```shell
rvm use 2.0.0-p648
gem install rubygems-update
gem install bundler
bundle install
```

## Copyright

Copyright (c) 2012 Josh Symonds.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
