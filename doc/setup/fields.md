# Fields

You'll have to define all the fields on the model and the data type of
each field. Every field on the object must be included here; if you miss
any they'll be completely bypassed during DynamoDB's initialization and
will not appear on the model objects.

By default, fields are assumed to be of type `string`. Other built-in
types are `integer`, `number`, `set`, `array`, `map`, `datetime`,
`date`, `boolean`, `binary`, `raw` and `serialized`. `array` and
`map` match List and Map DynamoDB types respectively. `raw` type means
you can store Ruby Array, Hash, String and numbers. If built-in types do
not suit you, you can use a custom field type represented by an
arbitrary class, provided that the class supports a compatible
serialization interface. The primary use case for using a custom field
type is to represent your business logic with high-level types, while
ensuring portability or backward-compatibility of the serialized
representation.

## Note on boolean type

The boolean fields are stored as DynamoDB boolean values by default.
Dynamoid can store boolean values as strings as well - `'t'` and `'f'`.
So if you want to change the default format of boolean field you can
easily achieve this with `store_as_native_boolean` field option:

```ruby
class Document
  include Dynamoid::Document

  field :active, :boolean, store_as_native_boolean: false
end
```

## Note on date type

By default date fields are persisted as days count since 1 January 1970
like UNIX time. If you prefer dates to be stored as ISO-8601 formatted
strings instead then set `store_as_string` to `true`

```ruby
class Document
  include Dynamoid::Document

  field :sent_on, :date, store_as_string: true
end
```

## Note on datetime type

By default datetime fields are persisted as UNIX timestamps with
millisecond precision in DynamoDB. If you prefer datetimes to be stored
as ISO-8601 formatted strings instead then set `store_as_string` to
`true`

```ruby
class Document
  include Dynamoid::Document

  field :sent_at, :datetime, store_as_string: true
end
```

**WARNING:** Fields in numeric format are stored with nanoseconds as a
fraction part and precision could be lost. That's why `datetime` field
in numeric format shouldn't be used as a range key.

You have two options if you need to use a `datetime` field as a range
key:
* string format
* store `datetime` values without milliseconds (e.g. cut
  them manually with `change` method - `Time.now.change(usec: 0)`

## Note on set type

`Dynamoid`'s type `set` is stored as DynamoDB's Set attribute type.
DynamoDB supports only Set of strings, numbers and binary. Moreover Set
*must* contain elements of the same type only.

In order to use some other `Dynamoid`'s types you can specify `of`
option to declare the type of set elements.

As a result of that DynamoDB limitation, in Dynamoid only the following
scalar types are supported (note: does not support `boolean`):
`integer`, `number`, `date`, `datetime`, `serializable` and custom
types.

```ruby
class Document
  include Dynamoid::Document

  field :tags, :set, of: :integer
end
```

It's possible to specify field options like `store_as_string` for
`datetime` field or `serializer` for `serializable` field for `set`
elements type:

```ruby
class Document
  include Dynamoid::Document

  field :values, :set, of: { serialized: { serializer: JSON } }
  field :dates, :set, of: { date: { store_as_string: true } }
  field :datetimes, :set, of: { datetime: { store_as_string: false } }
end
```

DynamoDB doesn't allow empty strings in fields configured as `set`.
Abiding by this restriction, when `Dynamoid` saves a document it removes
all empty strings in set fields.

## Note on array type

`Dynamoid`'s type `array` is stored as DynamoDB's List attribute type.
It can contain elements of different types (in contrast to Set attribute
type).

If you need to store in array field elements of `datetime`, `date`,
`serializable` or some custom type, which DynamoDB doesn't support
natively, you should specify element type with `of` option:

```ruby
class Document
  include Dynamoid::Document

  field :dates, :array, of: :date
end
```

## Note on binary type

By default binary fields are persisted as DynamoDB String value encoded
in the Base64 encoding. DynamoDB supports binary data natively. To use
it instead of String a `store_binary_as_native` field option should be
set:

```ruby
class Document
  include Dynamoid::Document

  field :image, :binary, store_binary_as_native: true
end
```

There is also a global config option `store_binary_as_native` that is
`false` by default as well.

## Magic Columns

You get magic columns of `id` (`string`), `created_at` (`datetime`), and
`updated_at` (`datetime`) for free.

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :rank, :integer
  field :number, :number
  field :joined_at, :datetime
  field :hash, :serialized
end
```

## Default Values

You can optionally set a default value on a field using either a plain
value or a lambda:

```ruby
field :actions_taken, :integer, default: 0
field :joined_at, :datetime, default: -> { Time.now }
```

## Aliases

It might be helpful to define an alias for an existing field when the
naming convention used for a table differs from conventions common in
Ruby:

```ruby
field :firstName, :string, alias: :first_name
```

This way, Dynamoid will generate
setter/getter/`<name>?`/`<name>_before_type_cast` methods for both the
original field name (`firstName`) and the alias (`first_name`).

```ruby
user = User.new(first_name: 'Michael')
user.first_name # => 'Michael'
user.firstName # => 'Michael'
```

## Custom Types

To use a custom type for a field, suppose you have a `Money` type.

```ruby
class Money
  # ... your business logic ...

  def dynamoid_dump
    'serialized representation as a string'
  end

  def self.dynamoid_load(_serialized_str)
    # parse serialized representation and return a Money instance
    Money.new(1.23)
  end
end

class User
  include Dynamoid::Document

  field :balance, Money
end
```

If you want to use a third-party class (which does not support
`#dynamoid_dump` and `.dynamoid_load`) as your field type, you can use
an adapter class providing `.dynamoid_dump` and `.dynamoid_load` class
methods for your third-party class. `.dynamoid_load` can remain the same
from the previous example; here we just add a level of indirection for
serializing. Example:

```ruby
# Third-party Money class
class Money; end

class MoneyAdapter
  def self.dynamoid_load(_money_serialized_str)
    Money.new(1.23)
  end

  def self.dynamoid_dump(money_obj)
    money_obj.value.to_s
  end
end

class User
  include Dynamoid::Document

  field :balance, MoneyAdapter
end
```

Lastly, you can control the data type of your custom-class-backed field
at the DynamoDB level. This is especially important if you want to use
your custom field as a numeric range or for number-oriented queries. By
default custom fields are persisted as a string attribute, but your
custom class can override this with a `.dynamoid_field_type` class
method, which would return either `:string` or `:number`.

DynamoDB may support some other attribute types that are not yet
supported by Dynamoid.

If a custom type implements `#==` method you can specify `comparable:
true` option in a field declaration to specify that an object is safely
comparable for the purpose of detecting changes. By default old and new
objects will be compared by their serialized representation.

```ruby
class Money
  # ...

  def ==(other)
    # comparison logic
  end
end

class User
  # ...

  field :balance, Money, comparable: true
end
```
