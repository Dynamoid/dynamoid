# Callbacks

Dynamoid also employs ActiveModel callbacks. Right now the following
callbacks are supported:
- `save` (before, after, around)
- `create` (before, after, around)
- `update` (before, after, around)
- `validation` (before, after)
- `destroy` (before, after, around)
- `after_touch`
- `after_initialize`
- `after_find`

Example:

```ruby
class User
  include Dynamoid::Document

  # ...

  before_save :set_default_password
  after_create :notify_friends
  after_destroy :delete_addresses
end
```
