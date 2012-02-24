# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It provides similar functionality to ActiveRecord and improves on Amazon's existing [HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html) by providing better searching tools, native association support, and a local adapter for offline development.

## Warning!

I'm still working on this gem a lot. Associations aren't working and that's a bummer, and you can only use the old-school ActiveRecord style finders like ```find_all_by_<attribute_name>``` or directly finding by an ID.

## Usage

Using Dynamoid is pretty simple. First you need to initialize it to get it going, so put code similar to this somewhere (a Rails initializer would be a great place for this if you're using Rails):

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

Inside your model:

```ruby
class User
   include Dynamoid::Document
   
   field :name
   field :email
   
   index :name
   index :email
   index [:name, :email]
   
end
```

Right now, you can only do a couple things with this amazing functionality:

```ruby
u = User.new(:name => 'Josh')
u.email = 'josh@joshsymonds.com'
u.save

u == User.find(u.id)
u == User.find_by_name('Josh')
u == User.find_by_name_and_email('Josh','josh@joshsymonds.com')
```

Not super exciting yet, true... but it's getting there!

## Credits

Dynamoid borrows code, structure, and even its name very liberally from the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without Mongoid to crib from none of this would have been possible, and I hope they don't mind me reusing their very awesome ideas to make DynamoDB just as accessible to the Ruby world as MongoDB.

## Running the tests

The tests can be run in the simple predictable way with ```rake```. However, if you provide environment variables for ACCESS_KEY and SECRET_KEY, the tests will use the aws_sdk adapter rather than the local adapter: ```ACCESS_KEY=<accesskey> SECRET_KEY=<secretkey> rake```

## Copyright

Copyright (c) 2012 Josh Symonds. See LICENSE.txt for further details.

