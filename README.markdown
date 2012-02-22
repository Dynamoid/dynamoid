# Dynamoid

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It provides similar functionality to ActiveRecord and improves on Amazon's existing [HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html) by providing better searching tools, native association support, and a local adapter for offline development.

## Warning!

I'm still working on this gem a lot. Right now it only uses the local offline adapter and has no ability to connect to DynamoDB. Associations aren't working and that's a bummer, and you can only use the old-school ActiveRecord style finders like ```find_all_by_<attribute_name>``` or directly finding by an ID.

## Usage

Using Dynamoid is pretty simple. First you need to initialize it to get it going, so put code similar to this somewhere:

```ruby
  Dynamoid.configure do |config|
    config.adapter = 'local' # This is the only adapter option presently. Eventually, an actual adapter that connects to DynamoDB will take its place.
    config.namespace = 'dynamoid' # To namespace tables created by Dynamoid from other tables you might have.
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

## Contributing to dynamoid
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Josh Symonds. See LICENSE.txt for further details.

