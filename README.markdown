# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It provides similar functionality to ActiveRecord and improves on Amazon's existing [HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html) by providing better searching tools, native association support, and a local adapter for offline development.

## Warning!

I'm still working on this gem a lot. It only provides .where(arguments) in its criteria chaining so far. More is coming though!

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your Gemfile:

```ruby
gem 'dynamoid'
```

Then you need to initialize it to get it going. Put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

```ruby
  Dynamoid.configure do |config|
    config.adapter = 'local' # This adapter allows offline development without connecting to the DynamoDB servers. Data is NOT persisted.
    # config.adapter = 'aws_sdk' # This adapter establishes a connection to the DynamoDB servers using's Amazon's own awful AWS gem.
    # config.access_key = 'access_key' # If connecting to DynamoDB, your access key is required.
    # config.secret_key = 'secret_key' # So is your secret key. 
    config.namespace = "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" # To namespace tables created by Dynamoid from other tables you might have.
    config.warn_on_scan = true # Output a warning to stdout when you perform a scan rather than a query on a table
  end

```

Once you have the configuration set up, just define models like this:

```ruby
class User
   include Dynamoid::Document # Documents automatically receive an 'id' field: you don't have to specify it.
   
   field :name           # Every field you have on the object must be specified here.
   field :email          # If you have fields that aren't specified they won't be attached to the object as methods.
   
   index :name           # Only specify indexes if you intend to perform queries on the specified fields.
   index :email          # Fields without indexes enjoy extremely poor performance as they must use 
   index [:name, :email] # scan rather than query.
   
   has_many :addresses   # Associations do not accept any options presently. The referenced
                         # model name must match exactly and the foreign key is always id.
   belongs_to :group     # If they detect a matching association on 
                         # the referenced model they'll auto-update that association.
   has_one :role         # Contrary to ActiveRecord, all associations are stored on the object,
                         # even if it seems like they'd be a foreign key association.
   has_and_belongs_to_many :friends
                         # There's no concept of embedding models yet but it's coming!
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

## Credits

Dynamoid borrows code, structure, and even its name very liberally from the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without Mongoid to crib from none of this would have been possible, and I hope they don't mind me reusing their very awesome ideas to make DynamoDB just as accessible to the Ruby world as MongoDB.

## Running the tests

The tests can be run in the simple predictable way with ```rake```. However, if you provide environment variables for ACCESS_KEY and SECRET_KEY, the tests will use the aws_sdk adapter rather than the local adapter: ```ACCESS_KEY=<accesskey> SECRET_KEY=<secretkey> rake```. Keep in mind this takes much, much longer than the local tests.

## Copyright

Copyright (c) 2012 Josh Symonds. See LICENSE.txt for further details.

