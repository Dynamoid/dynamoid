# Validations

Dynamoid bakes in ActiveModel validations, just like ActiveRecord does.

```ruby
class User
  include Dynamoid::Document

  # ...

  validates_presence_of :name
  validates_format_of :email, with: /@/
end
```

To see more usage and examples of ActiveModel validations, check out the
[ActiveModel validation
documentation](http://api.rubyonrails.org/classes/ActiveModel/Validations.html).

If you want to bypass model validation, pass `validate: false` to `save`
call:

```ruby
model.save(validate: false)
```
