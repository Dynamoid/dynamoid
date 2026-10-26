# Single Table Inheritance

The [Single Table Inheritance](https://www.martinfowler.com/eaaCatalog/singleTableInheritance.html) (STI) pattern maps an entire class hierarchy to a single DynamoDB table. An inheritance attribute (or discriminator)—by default named `type`—stores the class name for each item, allowing Dynamoid to instantiate the correct Ruby class when loading an item.

This pattern is useful when models share common fields and identity but require specialized behavior or extra attributes. For example, cars and trucks share baseline attributes like VIN and make, but cars define passenger seats while trucks specify cargo capacity.

## Inheritance Hierarchy

To set up Single Table Inheritance, create a base model and declare the `type` field. Subclasses inherit from the base model using standard Ruby inheritance:

```ruby
class Vehicle
  include Dynamoid::Document

  field :vin, :string
  field :make, :string
  field :model, :string
  field :type, :string
end

class Car < Vehicle
  field :seats, :integer
end

class Truck < Vehicle
  field :cargo_capacity, :integer
end
```

Subclasses inherit all fields, callbacks, and validations declared on the parent model. They also share the parent model's DynamoDB table:

```ruby
Vehicle.table_name # => "vehicles"
Car.table_name     # => "vehicles"
Truck.table_name   # => "vehicles"
```

> [!IMPORTANT]
> Unlike Active Record, where the underlying database table defines columns, Dynamoid requires an explicit `field :type, :string` declaration on the base model. If this field is omitted, Dynamoid will not assign type values or filter queries by type.

## Polymorphic Persistence and Querying

When saving models, instantiate the specific subclass directly. Dynamoid assigns the `type` attribute automatically so you never need to set type values by hand:

```ruby
car = Car.create(vin: '1HGCR2F83HA000000', make: 'Honda', model: 'Civic', seats: 5)
car.type # => "Car"

truck = Truck.create(vin: '1FTFW1ED4MF000000', make: 'Ford', model: 'F-150', cargo_capacity: 2000)
truck.type # => "Truck"
```

Loading an item through the base class returns an instance of the specific subclass:

```ruby
vehicle = Vehicle.find(car.id)

vehicle.class # => Car
vehicle.seats # => 5
```

Querying through the base class instantiates each returned item as its specific subclass. You can query across the entire hierarchy using shared fields or iterate across the collection:

```ruby
# Iterate across all vehicles lazily
Vehicle.all.each do |vehicle|
  puts "#{vehicle.model} (#{vehicle.class})"
end

# Filter across all subtypes using a shared field
hondas = Vehicle.where(make: 'Honda')
```

Conversely, querying through a subclass restricts results to that class and its descendants:

```ruby
Car.where(seats: 5).each do |car|
  puts car.seats
end
```

## Inheritance Field Configuration

By default, Dynamoid stores the class name in an attribute named `type`. If your table already uses `type` for another domain attribute, or if you prefer a more explicit name, configure `:inheritance_field` in the `table` method on the base model:

```ruby
class Vehicle
  include Dynamoid::Document

  table inheritance_field: :vehicle_type

  field :vehicle_type, :string
end

class Car < Vehicle
  field :seats, :integer
end
```

Subclasses inherit this table setting automatically:

```ruby
Vehicle.inheritance_field # => :vehicle_type
Car.inheritance_field     # => :vehicle_type

car = Car.create(seats: 5)
car.vehicle_type # => "Car"
```

## Class Mapping and Resolution

By default, Dynamoid stores the full Ruby class name in the type attribute. To decouple database values from Ruby class names, override `sti_name` on subclasses and map them with `sti_class_for` on the base model:

```ruby
class Vehicle
  include Dynamoid::Document

  field :type, :string

  def self.sti_class_for(type_name)
    case type_name
    when 'sedan'  then Car
    when 'pickup' then Truck
    end
  end
end

class Car < Vehicle
  field :seats, :integer

  def self.sti_name
    'sedan'
  end
end

class Truck < Vehicle
  field :cargo_capacity, :integer

  def self.sti_name
    'pickup'
  end
end
```

Subclasses persist using their custom identifiers, and `Vehicle.find` resolves them back to their respective classes:

```ruby
car = Car.create(seats: 5)
car.type # => "sedan"

truck = Truck.create(cargo_capacity: 2000)
truck.type # => "pickup"

Vehicle.find(car.id).class   # => Car
Vehicle.find(truck.id).class # => Truck
```

If only some subclasses define custom identifiers—or to support legacy type names alongside standard class names—call `super` to fall back to default constant lookup:

```ruby
class Vehicle
  # ...

  def self.sti_class_for(type_name)
    case type_name
    when 'sedan' then Car
    else
      super
    end
  end
end
```

{{#include ../_includes/feedback.md}}
