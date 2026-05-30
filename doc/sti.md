### STI

Dynamoid supports STI (Single Table Inheritance) like Active Record
does. You need just specify `type` field in a base class. Example:

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
#=> Cat
```

If you already have DynamoDB tables and the `type` field already exists and
has its own semantic it leads to a conflict. It's possible to tell
Dynamoid to use another field (even a non-existent one) instead of the `type`
one with the `inheritance_field` table option:

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
