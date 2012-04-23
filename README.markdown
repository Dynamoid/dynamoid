# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It provides similar functionality to ActiveRecord and improves on Amazon's existing [HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html) by providing better searching tools, native association support, and a local adapter for offline development.

DynamoDB is not like other document-based databases you might know, and is very different indeed from relational databases. It sacrifices anything beyond the simplest relational queries and transactional support to provide a fast, cost-efficient, and highly durable storage solution. If your database requires complicated relational queries and transaction support, then this modest Gem cannot provide them for you, and neither can DynamoDB. In those cases you would do better to look elsewhere for your database needs.

But if you want a fast, scalable, simple, easy-to-use database (and a Gem that supports it) then look no further!

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your Gemfile:

```ruby
gem 'dynamoid'
```

Then you need to initialize it to get it going. Put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

```ruby
  Dynamoid.configure do |config|
    config.adapter = 'local' # This adapter allows offline development without connecting to the DynamoDB servers. Data is *NOT* persisted.
    # config.adapter = 'aws_sdk' # This adapter establishes a connection to the DynamoDB servers using Amazon's own AWS gem.
    # config.access_key = 'access_key' # If connecting to DynamoDB, your access key is required.
    # config.secret_key = 'secret_key' # So is your secret key. 
    config.namespace = "dynamoid_app_development" # To namespace tables created by Dynamoid from other tables you might have.
    config.warn_on_scan = true # Output a warning to the logger when you perform a scan rather than a query on a table.
    config.partitioning = true # Spread writes randomly across the database. See "partitioning" below for more.
    config.partition_size = 200  # Determine the key space size that writes are randomly spread across.
    config.read_capacity = 100 # Read capacity for your tables
    config.write_capacity = 20 # Write capacity for your tables
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

### Fields

You'll have to define all the fields on the model and the data type of each field. Every field on the object must be included here; if you miss any they'll be completely bypassed during DynamoDB's initialization and will not appear on the model objects.

By default, fields are assumed to be of type ```:string```. But you can also use ```:integer```, ```:float```, ```:set```, ```:array```, ```:datetime```, and ```:serialized```. You get magic columns of id (string), created_at (datetime), and updated_at (datetime) for free.

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :rank, :integer
  field :number, :float
  field :joined_at, :datetime
  field :hash, :serialized
   
end
```

### Indexes

You can also define indexes on fields, combinations of fields, and one range field. Yes, only one range field: in DynamoDB tables can have at most one range index, so make good use of it! To make an index, just specify the fields you want it on, either single or in an array. If the entire index is a range, pass ```:range => true```. Otherwise, pass the attribute that will become the range key. The only range attributes you can use right now are integers, floats, and datetimes. If you pass a string as a range key likely DynamoDB will complain a lot.

```ruby
class User
  include Dynamoid::Document

  ...
   
  index :name           
  index :email          
  index [:name, :email] 
  index :created_at, :range => true
  index :name, :range_key => :joined_at
  
end
```

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

Dynamoid's syntax is very similar to ActiveRecord's.

```ruby
u = User.new(:name => 'Josh')
u.email = 'josh@joshsymonds.com'
u.save
```

Save forces persistence to the datastore: a unique ID is also assigned, but it is a string and not an auto-incrementing number.

```ruby
u.id # => "3a9f7216-4726-4aea-9fbc-8554ae9292cb"
```

Along with persisting the model's attributes, indexes are automatically updated on save. To use associations, you use association methods very similar to ActiveRecord's:

```ruby
address = u.addresses.create
address.city = 'Chicago'
address.save
```

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

If you have a range index, Dynamoid provides a number of additional other convenience methods to make your life a little easier:

```ruby
User.where("created_at.gt" => DateTime.now - 1.day).all
User.where("created_at.lt" => DateTime.now - 1.day).all
```

It also supports .gte and .lte. Turning those into symbols and allowing a Rails SQL-style string syntax is in the works. You can only have one range argument per query, because of DynamoDB's inherent limitations, so use it sensibly!

## Partitioning, Provisioning, and Performance

DynamoDB achieves much of its speed by relying on a random pattern of writes and reads: internally, hash keys are distributed across servers, and reading from two consecutive servers is much faster than reading from the same server twice. Of course, many of our applications request one key (like a commonly used role, a superuser, or a very popular product) much more frequently than other keys. In DynamoDB, this will result in lowered throughput and slower response times, and is a design pattern we should try to avoid.

Dynamoid attempts to obviate this problem transparently by employing a partitioning strategy to divide up keys randomly across DynamoDB's servers. Each ID is assigned an additional number (by default 0 to 199, but you can increase the partition size in Dynamoid's configuration) upon save; when read, all 200 hashes are retrieved simultaneously and the most recently updated one is returned to the application. This results in a significant net performance increase, and is usually invisible to the application itself. It does, however, bring up the important issue of provisioning your DynamoDB tables correctly.

When your read or write provisioning exceed your table's allowed throughput, DynamoDB will wait on connections until throughput is available again. This will appear as very, very slow requests and can be somewhat frustrating. Partitioning significantly increases the amount of throughput tables will experience; though DynamoDB will ignore keys that don't exist, if you have 20 partitioned keys representing one object, all will be retrieved every time the object is requested. Ensure that your tables are set up for this kind of throughput, or turn provisioning off, to make sure that DynamoDB doesn't throttle your requests.

## Credits

Dynamoid borrows code, structure, and even its name very liberally from the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without Mongoid to crib from none of this would have been possible, and I hope they don't mind me reusing their very awesome ideas to make DynamoDB just as accessible to the Ruby world as MongoDB.

Also, without contributors the project wouldn't be nearly as awesome. So many thanks to:

* [Anantha Kumaran](https://github.com/ananthakumaran)
* [Jason Dew](https://github.com/jasondew)

## Running the tests

The tests can be run in the simple predictable way with ```rake```. However, if you provide environment variables for ACCESS_KEY and SECRET_KEY, the tests will use the aws_sdk adapter rather than the local adapter: ```ACCESS_KEY=<accesskey> SECRET_KEY=<secretkey> rake```. Keep in mind this takes much, much longer than the local tests.

## Copyright

Copyright (c) 2012 Josh Symonds. See LICENSE.txt for further details.

