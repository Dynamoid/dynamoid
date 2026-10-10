# Single Table Inheritance (STI)

Dynamoid supports Single Table Inheritance (STI) similar to Active Record. STI allows you to represent an inheritance hierarchy of related Ruby classes within a single DynamoDB table.

## Defining an STI Hierarchy

To enable STI, declare a `type` field in the base model class:

```ruby
class Animal
  include Dynamoid::Document

  field :name, :string
  field :type, :string
end

class Cat < Animal
  field :lives, :integer, default: 9
end

class Dog < Animal
  field :bark_volume, :integer
end
```

When an instance of a subclass is saved, Dynamoid automatically populates the `type` attribute with the subclass name:

```ruby
cat = Cat.create(name: 'Morgan')
cat.type # => "Cat"

dog = Dog.create(name: 'Buddy', bark_volume: 5)
dog.type # => "Dog"
```

## Querying and Polymorphism

When querying through the base class, Dynamoid inspects the `type` attribute on each returned item and instantiates the correct Ruby subclass:

```ruby
# Querying via base class returns polymorphic instances
animal = Animal.find(cat.id)
animal.class # => Cat
animal.lives # => 9

# Querying all animals returns mixed subclasses
animals = Animal.all
# => [#<Cat id: "...", name: "Morgan">, #<Dog id: "...", name: "Buddy">]
```

## Customizing the Inheritance Field

By default, Dynamoid uses an attribute named `type` as the STI discriminator column. If your DynamoDB table already uses `type` for another domain attribute, or if you prefer a more descriptive attribute name, override the discriminator column name by passing `:inheritance_field` to the `table` method on the base class:

```ruby
class Vehicle
  include Dynamoid::Document

  table inheritance_field: :vehicle_type

  field :vehicle_type, :string
  field :vin, :string
end

class Truck < Vehicle
  field :payload_capacity_lbs, :integer
end
```

All subclasses inherit this table configuration automatically:

```ruby
Vehicle.inheritance_field # => :vehicle_type
Truck.inheritance_field   # => :vehicle_type

truck = Truck.create(vin: '1HGCR2F83HA000000')
truck.vehicle_type # => "Truck"
```

> [!NOTE]
> Like any other attribute, the custom inheritance field must be explicitly declared on the base model using `field :custom_field, :string`.
