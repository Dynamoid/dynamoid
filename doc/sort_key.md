### Sort key

Along with partition key table may have a sort key. In order to declare
it in a model `range` class method should be used:

```ruby
class Post
  include Dynamoid::Document

  range :posted_at, :datetime
end
```

Second argument, type, is optional. Default type is `string`.
