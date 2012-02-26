# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It provides similar functionality to ActiveRecord and improves on Amazon's existing [HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html) by providing better searching tools, native association support, and a local adapter for offline development.

## Warning!

I'm still working on this gem a lot. You can only use the old-school ActiveRecord style finders like ```find_all_by_<attribute_name>``` or directly finding by an ID.

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your Gemfile:

```ruby
gem 'dynamoid'
```

Then you need to initialize it to get it going, so put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

```ruby
  Dynamoid.configure do |config|
    config.adapter = 'local' # This adapter allows offline development without connecting to the DynamoDB servers.
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

### Usage

Right now, you can only do a couple things with this amazing functionality:

```ruby
u = User.new(:name => 'Josh')
u.email = 'josh@joshsymonds.com'
u.save

address = u.addresses.create
address.city = 'Chicago'
address.save

u == User.find(u.id)
u == User.find_by_name('Josh')
u.addresses == User.find_by_name_and_email('Josh','josh@joshsymonds.com').addresses
```

Not super exciting yet, true... but it's getting there!

## Credits

Dynamoid borrows code, structure, and even its name very liberally from the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without Mongoid to crib from none of this would have been possible, and I hope they don't mind me reusing their very awesome ideas to make DynamoDB just as accessible to the Ruby world as MongoDB.

## Running the tests

The tests can be run in the simple predictable way with ```rake```. However, if you provide environment variables for ACCESS_KEY and SECRET_KEY, the tests will use the aws_sdk adapter rather than the local adapter: ```ACCESS_KEY=<accesskey> SECRET_KEY=<secretkey> rake```. Keep in mind this takes much, much longer than the local tests.

## Copyright

Copyright (c) 2012 Josh Symonds. See LICENSE.txt for further details.

