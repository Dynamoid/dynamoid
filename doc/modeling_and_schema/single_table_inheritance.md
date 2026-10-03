# Single Table Inheritance

The [Single Table Inheritance](https://www.martinfowler.com/eaaCatalog/singleTableInheritance.html) (STI) pattern maps an entire class hierarchy to a single DynamoDB table. An inheritance attribute (or discriminator)—by default named `type`—stores the class name for each item, allowing Dynamoid to instantiate the correct Ruby class when loading an item.

This pattern is useful when models share common fields and identity but require specialized behavior or extra attributes. For example, cars and trucks share baseline attributes like VIN and make, but cars define passenger seats while trucks specify cargo capacity.

## Inheritance Hierarchy

To set up Single Table Inheritance, create a base model and declare the `type` field. Subclasses inherit from the base model using standard Ruby inheritance:

```ruby
class Vehicle
  include Dynamoid::Document

  field :make
  field :model
  field :type
end

class Car < Vehicle
  field :seats, :integer
end

class Truck < Vehicle
  field :cargo_capacity, :integer
end
```

Subclasses inherit all fields, associations, callbacks, and validations declared on the parent model, while any declared on a subclass apply only to that subclass and its descendants. Because the entire hierarchy shares the base model's DynamoDB table, declare table options (`table`) and secondary indexes on the base model:

```ruby
Vehicle.table_name # => "vehicles"
Car.table_name     # => "vehicles"
Truck.table_name   # => "vehicles"
```

> [!IMPORTANT]
> Unlike Active Record, where the underlying database table defines columns, Dynamoid requires an explicit `field :type` declaration on the base model. If this field is omitted, Dynamoid will not assign type values or filter queries by type.

## Polymorphic Persistence and Querying

When initializing or saving models, instantiate the specific subclass directly. Dynamoid populates the `type` attribute automatically so you never need to set type values by hand:

```ruby
car = Car.create(make: 'Honda', model: 'Civic', seats: 5)
car.type # => "Car"

truck = Truck.create(make: 'Ford', model: 'F-150', cargo_capacity: 2000)
truck.type # => "Truck"
```

If you need to instantiate a model dynamically from an attributes hash that contains the `type` attribute, use `build` (or `create`) on the base class rather than `new`:

```ruby
vehicle = Vehicle.build(type: 'Car', make: 'Honda', model: 'Civic', seats: 5)
vehicle.class # => Car
```

Loading an item through the base class returns an instance of the specific subclass:

```ruby
vehicle = Vehicle.find(car.id)

vehicle.class # => Car
vehicle.seats # => 5
```

Querying through the base class searches across the entire hierarchy and instantiates each returned item as its specific subclass:

```ruby
vehicles = Vehicle.all
hondas   = Vehicle.where(make: 'Honda').all
```

Conversely, querying through a subclass restricts results to that class and its descendants:

```ruby
cars       = Car.all
honda_cars = Car.where(make: 'Honda').all
```

## Inheritance Field Configuration

If your table already uses `type` for another domain attribute, or if you prefer a different attribute name, configure `:inheritance_field` in the `table` method on the base model and declare the corresponding field:

```ruby
class Vehicle
  include Dynamoid::Document

  table inheritance_field: :vehicle_type

  field :vehicle_type
end

class Car < Vehicle
end

car = Car.create
car.vehicle_type # => "Car"
```

## Class Mapping and Resolution

To decouple database type values from Ruby class names, override `sti_name` on subclasses and map them with `sti_class_for` on the base model:

```ruby
class Vehicle
  include Dynamoid::Document

  field :type

  def self.sti_class_for(type_name)
    case type_name
    when 'sedan'  then Car
    when 'pickup' then Truck
    else
      super
    end
  end
end

class Car < Vehicle
  def self.sti_name
    'sedan'
  end
end

class Truck < Vehicle
  def self.sti_name
    'pickup'
  end
end
```

Calling `super` in the `else` branch falls back to default constant lookup, resolving standard class names (such as `'Vehicle'` or subclasses without a custom `sti_name`) and raising `Dynamoid::Errors::SubclassNotFound` for unknown values.

Subclasses persist using their custom identifiers, and `Vehicle.find` resolves them back to their respective classes:

```ruby
car = Car.create
car.type # => "sedan"

truck = Truck.create
truck.type # => "pickup"

Vehicle.find(car.id).class   # => Car
Vehicle.find(truck.id).class # => Truck
```

{{#include ../_includes/feedback.md}}
