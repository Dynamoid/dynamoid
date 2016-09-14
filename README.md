# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It
provides similar functionality to ActiveRecord and improves on
Amazon's existing
[HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html)
by providing better searching tools and native association support.

DynamoDB is not like other document-based databases you might know, and is very different indeed from relational databases. It sacrifices anything beyond the simplest relational queries and transactional support to provide a fast, cost-efficient, and highly durable storage solution. If your database requires complicated relational queries and transaction support, then this modest Gem cannot provide them for you, and neither can DynamoDB. In those cases you would do better to look elsewhere for your database needs.

But if you want a fast, scalable, simple, easy-to-use database (and a Gem that supports it) then look no further!

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your Gemfile:

```ruby
gem 'dynamoid', '~> 1'
```
## Prerequisities

Dynamoid depends on the aws-sdk, and this is tested on the current version of aws-sdk (~> 2), rails (~> 4).
Hence the configuration as needed for aws to work will be dealt with by aws setup.

Here are the steps to setup aws-sdk.

```ruby
gem 'aws-sdk', '~>2'
```

(or) include the aws-sdk in your Gemfile.

**NOTE:** Dynamoid-1.0 doesn't support aws-sdk Version 1 (Use Dynamoid Major Version 0 for aws-sdk 1)

Configure AWS access:
[Reference](https://github.com/aws/aws-sdk-ruby)

For example, to configure AWS access:

Create config/initializers/aws.rb as follows:

```ruby

  Aws.config.update({
    region: 'us-west-2',
    credentials: Aws::Credentials.new('REPLACE_WITH_ACCESS_KEY_ID', 'REPLACE_WITH_SECRET_ACCESS_KEY'),
  })

```

For a full list of the DDB regions, you can go
[here](http://docs.aws.amazon.com/general/latest/gr/rande.html#ddb_region).

Then you need to initialize Dynamoid config to get it going. Put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

```ruby
  Dynamoid.configure do |config|
    config.adapter = 'aws_sdk_v2' # This adapter establishes a connection to the DynamoDB servers using Amazon's own AWS gem.
    config.namespace = "dynamoid_app_development" # To namespace tables created by Dynamoid from other tables you might have. Set to nil to avoid namespacing.
    config.warn_on_scan = true # Output a warning to the logger when you perform a scan rather than a query on a table.
    config.read_capacity = 5 # Read capacity for your tables
    config.write_capacity = 5 # Write capacity for your tables
    config.endpoint = 'http://localhost:3000' # [Optional]. If provided, it communicates with the DB listening at the endpoint. This is useful for testing with [Amazon Local DB] (http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html).
  end

```

Once you have the configuration set up, you need to move on to making models.

## Setup

You *must* include ```Dynamoid::Document``` in every Dynamoid model.

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

  table :name => :awesome_users, :key => :user_id, :read_capacity => 5, :write_capacity => 5
end
```

These fields will not change an existing table: so specifying a new read_capacity and write_capacity here only works correctly for entirely new tables. Similarly, while Dynamoid will look for a table named `awesome_users` in your namespace, it won't change any existing tables to use that name; and if it does find a table with the correct name, it won't change its hash key, which it expects will be user_id. If this table doesn't exist yet, however, Dynamoid will create it with these options.

### Fields

You'll have to define all the fields on the model and the data type of each field. Every field on the object must be included here; if you miss any they'll be completely bypassed during DynamoDB's initialization and will not appear on the model objects.

By default, fields are assumed to be of type ```:string```. Other built-in types are
```:integer```, ```:number```, ```:set```, ```:array```, ```:datetime```, ```:boolean```, and ```:serialized```.
If built-in types do not suit you, you can use a custom field type represented by an arbitrary class, provided that the class supports a compatible serialization interface.
The primary use case for using a custom field type is to represent your business logic with high-level types, while ensuring portability or backward-compatibility of the serialized representation.

You get magic columns of id (string), created_at (datetime), and updated_at (datetime) for free.

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

You can optionally set a default value on a field using either a plain value or a lambda:

```ruby
  field :actions_taken, :integer, {default: 0}
  field :joined_at, :datetime, {default: ->(){Time.now}}
```

To use a custom type for a field, suppose you have a `Money` type.

```ruby
  class Money
    # ... your business logic ...

    def dynamoid_dump
      "serialized representation as a string"
    end

    def self.dynamoid_load(serialized_str)
      # parse serialized representation and return a Money instance
      Money.new(...)
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
      Money.new(...)
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
number-oriented queries.  By default custom fields are persisted as a string attribute, but
your custom class can override this with a `.dynamoid_field_type` class method, which would
return either `:string` or `:number`.
(DynamoDB supports some other attribute types, but Dynamoid does not yet.)


### Associations

Just like in ActiveRecord (or your other favorite ORM), Dynamoid uses associations to create links between models.

The only supported associations (so far) are ```has_many```, ```has_one```, ```has_and_belongs_to_many```, and ```belongs_to```. Associations are very simple to create: just specify the type, the name, and then any options you'd like to pass to the association. If there's an inverse association either inferred or specified directly, Dynamoid will update both objects to point at each other.

```ruby
class User
  include Dynamoid::Document

  ...

  has_many :addresses
  has_many :students, :class => User
  belongs_to :teacher, :class_name => :user
  belongs_to :group
  has_one :role
  has_and_belongs_to_many :friends, :inverse_of => :friending_users

end

class Address
  include Dynamoid::Document

  ...

  belongs_to :address # Automatically links up with the user model

end
```

Contrary to what you'd expect, association information is always contained on the object specifying the association, even if it seems like the association has a foreign key. This is a side effect of DynamoDB's structure: it's very difficult to find foreign keys without an index. Usually you won't find this to be a problem, but it does mean that association methods that build new models will not work correctly -- for example, ```user.addresses.new``` returns an address that is not associated to the user. We'll be correcting this soon.

### Validations

Dynamoid bakes in ActiveModel validations, just like ActiveRecord does.

```ruby
class User
  include Dynamoid::Document

  ...

  validates_presence_of :name
  validates_format_of :email, :with => /@/
end
```

To see more usage and examples of ActiveModel validations, check out the [ActiveModel validation documentation](http://api.rubyonrails.org/classes/ActiveModel/Validations.html).

### Callbacks

Dynamoid also employs ActiveModel callbacks. Right now, callbacks are defined on ```save```, ```update```, ```destroy```, which allows you to do ```before_``` or ```after_``` any of those.

```ruby
class User
  include Dynamoid::Document

  ...

  before_save :set_default_password
  after_create :notify_friends
  after_destroy :delete_addresses
end
```

## Usage

### Object Creation

Dynamoid's syntax is generally very similar to ActiveRecord's. Making new objects is simple:

```ruby
u = User.new(:name => 'Josh')
u.email = 'josh@joshsymonds.com'
u.save
```

Save forces persistence to the datastore: a unique ID is also assigned, but it is a string and not an auto-incrementing number.

```ruby
u.id # => "3a9f7216-4726-4aea-9fbc-8554ae9292cb"
```

To use associations, you use association methods very similar to ActiveRecord's:

```ruby
address = u.addresses.create
address.city = 'Chicago'
address.save
```

### Querying

Querying can be done in one of three ways:

```ruby
Address.find(address.id)              # Find directly by ID.
Address.where(:city => 'Chicago').all # Find by any number of matching criteria... though presently only "where" is supported.
Address.find_by_city('Chicago')       # The same as above, but using ActiveRecord's older syntax.
```

And you can also query on associations:

```ruby
u.addresses.where(:city => 'Chicago').all
```

But keep in mind Dynamoid -- and document-based storage systems in general -- are not drop-in replacements for existing relational databases. The above query does not efficiently perform a conditional join, but instead finds all the user's addresses and naively filters them in Ruby. For large associations this is a performance hit compared to relational database engines.

You can also limit the number of evaluated records, or select a record from which to start, to support pagination:

```ruby
Address.eval_limit(5).start(address) # Only 5 addresses.
```

For large queries that return many rows, Dynamoid can use AWS' support for requesting documents in batches:

```ruby
#Do some maintenance on the entire table without flooding DynamoDB
Address.all(batch_size: 100).each { |address| address.do_some_work; sleep(0.01) }
Address.limit(10_000).batch(100). each { … } #batch specified as part of a chain
```

### Consistent Reads

Querying supports consistent reading. By default, DynamoDB reads are eventually consistent: if you do a write and then a read immediately afterwards, the results of the previous write may not be reflected. If you need to do a consistent read (that is, you need to read the results of a write immediately) you can do so, but keep in mind that consistent reads are twice as expensive as regular reads for DynamoDB.

```ruby
Address.find(address.id, :consistent_read => true)  # Find an address, ensure the read is consistent.
Address.where(:city => 'Chicago').consistent.all    # Find all addresses where the city is Chicago, with a consistent read.
```

### Range Finding

If you have a range index, Dynamoid provides a number of additional other convenience methods to make your life a little easier:

```ruby
User.where("created_at.gt" => DateTime.now - 1.day).all
User.where("created_at.lt" => DateTime.now - 1.day).all
```

It also supports .gte and .lte. Turning those into symbols and allowing a Rails SQL-style string syntax is in the works. You can only have one range argument per query, because of DynamoDB's inherent limitations, so use it sensibly!

## Concurrency

Dynamoid supports basic, ActiveRecord-like optimistic locking on save operations. Simply add a `lock_version` column to your table like so:

```ruby
class MyTable
  ...

  field :lock_version, :integer

  ...
end
```

In this example, all saves to `MyTable` will raise an `Dynamoid::Errors::StaleObjectError` if a concurrent process loaded, edited, and saved the same row. Your code should trap this exception, reload the row (so that it will pick up the newest values), and try the save again.

Calls to `update` and `update!` also increment the `lock_version`, however they do not check the existing value. This guarantees that a update operation will raise an exception in a concurrent save operation, however a save operation will never cause an update to fail. Thus, `update` is useful & safe only for doing atomic operations (e.g. increment a value, add/remove from a set, etc), but should not be used in a read-modify-write pattern.

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
    Dynamoid.included_models.each(&:create_table)
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

\* Current Maintianers

## Running the tests

Running the tests is fairly simple. You should have an instance of DynamoDB running locally. Follow this steps to be able to run the tests:

 * First download and unpack the latest version of DynamoDB.

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

[![Build Status](https://travis-ci.org/Dynamoid/Dynamoid.svg)](https://travis-ci.org/Dynamoid/Dynamoid)
[![Coverage Status](https://coveralls.io/repos/Dynamoid/Dynamoid/badge.svg?branch=master&service=github)](https://coveralls.io/github/Dynamoid/Dynamoid?branch=master)

## Copyright

Copyright (c) 2012 Josh Symonds.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
