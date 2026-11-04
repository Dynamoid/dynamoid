# Fields & Data Types

DynamoDB tables are schemaless beyond their primary keys: items can contain arbitrary attributes, and an attribute only exists when assigned a value. Dynamoid brings structure to this model by letting you declare an explicit attribute schema directly on your Ruby models.

Attributes on a Dynamoid model must be declared using `field` (or `range` for sort keys). Undeclared attributes stored in DynamoDB are safely ignored when loading items, preventing unexpected database fields from polluting in-memory models:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :email
  field :age, :integer
end
```

Field declarations do far more than define standard Ruby getter and setter methods. They establish an application-level schema that manages the translation between Ruby models and DynamoDB:

* *Type casting* — casts assigned values into declared Ruby types (such as strings, integers, dates, arrays, or hashes).
* *Non-native types* — serializes types DynamoDB lacks natively (dates, timestamps, and custom types).
* *Time zone awareness* — normalizes timestamps to a uniform storage time zone (UTC by default) and presents them in the application's time zone.
* *Typed collections* — enforces and casts element types inside sets and arrays.
* *Constraint handling* — handles DynamoDB limitations like prohibited empty sets.

## Declaring Fields & Attribute Access

You define attributes and sort keys using class-level macros, which automatically generate idiomatic Ruby reader, writer, and query accessors on model instances.

### Declaring Fields

Declare attributes on your model by calling the `field` class method. It accepts the attribute name as a symbol (or string), an optional data type, and configuration settings:

```ruby
class User
  include Dynamoid::Document

  field :email                           # Type omitted
  field :age, :integer                   # Explicit type
  field :active, :boolean, default: true # Explicit type and options
end
```

When the data type argument is omitted, Dynamoid defaults to `:string`.

### Declaring Sort Key

To declare a sort key for a composite primary key, use the `range` class method instead of `field`:

```ruby
class Order
  include Dynamoid::Document

  range :placed_at, :datetime
end
```

The `range` method declares a field with the exact same data types and options as `field`, while registering that attribute as the table's composite sort key (see [Table Mapping & Provisioning](table_mapping_and_provisioning.md#sort-key)).

### Generated Accessors

For every declared field, Dynamoid generates three instance methods on your model:

* *Reader (`<attribute>`)* — returns the type-casted attribute value.
* *Writer (`<attribute>=`)* — type casts the incoming value and updates in-memory storage.
* *Predicate query (`<attribute>?`)* — returns `true` if the attribute has a value other than `false` or `nil`.

```ruby
user = User.new

user.email # => nil
user.email? # => false

user.email = "ada@example.com"
user.email # => "ada@example.com"
user.email? # => true
```

If a declared field name conflicts with an existing Ruby method on the class, Dynamoid logs a warning during class definition to alert you of the method redefinition.

### Direct Attribute Access

In addition to generated reader and writer methods, you can read and write attributes directly by name using `read_attribute` and `write_attribute`, or their hash-style aliases `[]` and `[]=`:

```ruby
# Read attributes directly by name
user.read_attribute(:age) # => 35
user[:age]                # => 35

# Write attributes directly by name
user.write_attribute(:age, 36)
user[:age] = 36
```

To retrieve all type-casted attributes currently loaded on the instance, call `attributes`:

```ruby
user.attributes
# => { id: "a8f5c3...", email: "ada@example.com", age: 36, active: true, ... }
```

You can also read all unconverted values assigned before type casting by calling `attributes_before_type_cast`, or inspect a single attribute's raw input with `read_attribute_before_type_cast(:age)`.

## General Field Options

The `field` macro accepts configuration options to customize attribute behavior. While type-specific options (such as `:of` and `:store_as_string`) are detailed in [Data Types](#data-types), general options such as `:default` and `:alias` can be applied to any field declaration.

### Default Values

Fields can declare default values that are applied when no value is passed during initialization. Defaults can be static values or dynamic callables:

```ruby
class User
  include Dynamoid::Document

  field :status, :string, default: 'active'
  field :confirmation_token, :string, default: -> { SecureRandom.hex(16) }
end
```

When a default is specified as a callable object (such as a lambda or proc responding to `#call`), Dynamoid evaluates the block anew for each initialized model instance. For static values, mutable objects (such as strings or arrays) are duplicated upon initialization so separate instances do not share state.

### Attribute Aliasing

Legacy DynamoDB tables or external systems often use camelCase or uppercase attribute names (such as `firstName` or `ORDER_STATUS`). You can define an idiomatic Ruby snake_case alias using the `:alias` option:

```ruby
class User
  include Dynamoid::Document

  field :firstName, :string, alias: :first_name
end
```

When an alias is specified, Dynamoid generates reader, writer, predicate query, and raw reader methods for both names:

```ruby
# Initialize with the declared name
user = User.new(firstName: "Ada")
user.first_name # => "Ada"

# Initialize with the alias
user = User.new(first_name: "Ada")
user.firstName  # => "Ada"

# Updating via either name updates the underlying attribute
user.first_name = "Grace"
user.firstName  # => "Grace"
```

In the underlying DynamoDB item, the attribute is stored under the primary declared name (`firstName`).

## Data Types

Dynamoid maps declared fields to native [DynamoDB data types](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.DataTypes) (scalar, document, and set types), while providing type casting for standard Ruby classes, collections, and custom types.

| Dynamoid Type | Ruby Class | DynamoDB Type | Description |
|---|---|---|---|
| [`:string`](#strings) | `String` | String | UTF-8 text string. |
| [`:integer`](#integers) | `Integer` | Number | Whole number; truncates fractions. |
| [`:number`](#numbers) | `BigDecimal` | Number | Arbitrary-precision decimal. |
| [`:boolean`](#booleans) | `TrueClass` / `FalseClass` | Boolean (default) or String | Boolean value (`true` or `false`). |
| [`:binary`](#binary) | `String` | String (default, Base64) or Binary | Raw binary data. |
| [`:datetime`](#datetimes) | `DateTime` | Number (default) or String | Timestamp with sub-second precision. |
| [`:date`](#dates) | `Date` | Number (default) or String | Calendar date without time or time zone. |
| [`:set`](#sets) | `Set` | String, Number, or Binary Set | Homogeneous collection of unique scalar values. |
| [`:array`](#arrays) | `Array` | List | Ordered collection of heterogeneous elements. |
| [`:map`](#maps) | `Hash` | Map | Key-value dictionary. |
| [`:raw`](#untyped-fields-raw) | Any supported Ruby class (`Hash`, `Array`, etc.) | Any native DynamoDB type | Preserves values and nested structures without type casting. |
| [`:serialized`](#object-serialization-serialized) | Any serializable object | String | Serializes arbitrary objects (YAML by default). |
| [Custom Type](#custom-types) | User-defined class | Any native DynamoDB type | Domain object with custom dump and load methods. |

### Scalar Types

Scalar types represent single primitive values mapped to DynamoDB's native scalar storage formats.

#### Strings

On assignment, Dynamoid casts values into a `String` via `#to_s` (booleans become `'t'` or `'f'`). String objects are duplicated on assignment, so mutating the original string does not affect the model attribute. In-memory attributes always return a `String` (or `nil` if unset).

In DynamoDB, strings are persisted as native String attributes, which store Unicode text encoded in UTF-8. Strings assigned in other encodings (such as ISO-8859-1) are transcoded to UTF-8 on save, and reading from DynamoDB returns a UTF-8 string. If a string contains arbitrary binary data that cannot be encoded as UTF-8, saving raises a `JSON::GeneratorError`; use [Binary](#binary) instead.

By default, assigning an empty string (`""`) causes Dynamoid to persist the attribute as `nil`. To preserve empty strings in DynamoDB, set `config.store_empty_string_as_nil = false`.

#### Integers

On assignment, Dynamoid casts values into an `Integer` by calling `#to_i` on any object that responds to it, while booleans map explicitly to `1` (`true`) or `0` (`false`). For example, floats are truncated towards zero, numeric strings like `"1abc"` become `1`, and non-numeric strings like `"abc"` become `0`.

Blank strings (`""` or `" "`), non-finite floats (`Float::NAN`, `Float::INFINITY`), and objects that do not respond to `#to_i` cast to `nil`.

In DynamoDB, integers are stored as native Number attributes. When loaded from DynamoDB, attributes are returned as `Integer` (or `nil` if unset).

#### Numbers

The `:number` type manages arbitrary-precision decimals, currencies, ratings, and floating-point data.

On assignment, Dynamoid casts numeric inputs (including floats, integers, symbols, and numeric strings) into `BigDecimal` via `#to_d` to prevent IEEE 754 floating-point rounding errors. Booleans cast to `1` (`true`) or `0` (`false`), while blank strings, non-finite floats, and objects without `#to_d` cast to `nil`.

In DynamoDB, numbers are stored as native Number attributes. When loaded from DynamoDB, attributes are returned as `BigDecimal` (or `nil` if unset).

#### Booleans

On assignment, Dynamoid casts inputs into `true` or `false`. Values recognized as `false` include `false`, `'false'`, `'FALSE'`, `0`, `'0'`, `'f'`, `'F'`, `'off'`, and `'OFF'`. Empty strings cast to `nil`. All other values cast to `true`. In-memory attributes always return `true`, `false`, or `nil`.

In DynamoDB, boolean fields are stored by default as native Boolean attributes:

```ruby
class User
  include Dynamoid::Document

  field :active, :boolean
end

user = User.create!(active: true)

# DynamoDB item attribute:
# "active": true (Boolean)
```

To store booleans using legacy single-character strings (`'t'` or `'f'`) for compatibility with older tables, set `store_as_native_boolean: false` on the field, or set `config.store_boolean_as_native = false` globally:

```ruby
class User
  include Dynamoid::Document

  field :active, :boolean, store_as_native_boolean: false
end

user = User.create!(active: true)

# DynamoDB item attribute:
# "active": "t" (String)
```

#### Binary

The `:binary` type stores arbitrary binary data, such as images, compressed payloads, or encrypted buffers.

By default, binary fields are stored in DynamoDB as Base64-encoded String attributes, and accept binary strings:

```ruby
class User
  include Dynamoid::Document

  field :avatar, :binary
end

user = User.create!(avatar: "\x00\x88\xFF".b)

# DynamoDB item attribute:
# "avatar": "AIj/" (String, Base64-encoded)
```

To store raw binary data natively as DynamoDB Binary attributes, pass `store_as_native_binary: true` on the field, or set `config.store_binary_as_native = true` globally. Native binary fields accept `String`, `StringIO`, or `IO` objects (such as an open `File`) directly:

```ruby
class User
  include Dynamoid::Document

  field :avatar, :binary, store_as_native_binary: true
end

# Accepts binary String, StringIO, or IO objects (such as an open File):
File.open("avatar.png", "rb") do |file|
  user = User.create!(avatar: file)
end

# DynamoDB item attribute:
# "avatar": <raw bytes> (Binary)
```

When loaded from DynamoDB, binary attributes are always returned as `String` instances with `ASCII-8BIT` (binary) encoding in either storage mode. Objects that are neither strings nor IO objects assigned to binary fields are converted via `#to_s`.

#### DateTimes

The `:datetime` type manages timestamps with sub-second precision.

On assignment, Dynamoid casts values (including `Time`, `DateTime`, `Date`, and formatted strings) into `DateTime` via `#to_datetime`. When parsing date strings without an explicit time zone offset, Dynamoid assumes the offset configured by `config.application_timezone`. When loaded from DynamoDB, attributes are returned as `DateTime` adjusted to `config.application_timezone` (see [Time Zones](#time-zones)).

In DynamoDB, datetime fields are stored by default as numeric timestamps (seconds and nanoseconds since the Unix epoch) in Number attributes:

```ruby
class Order
  include Dynamoid::Document

  field :placed_at, :datetime
end

order = Order.create!(placed_at: "2026-10-11 12:00:00")

# DynamoDB item attribute:
# "placed_at": 1791720000.0 (Number, seconds since Unix epoch)
```

To store timestamps as human-readable ISO-8601 strings, pass `store_as_string: true` on the field, or set `config.store_datetime_as_string = true` globally. When stored as strings, timestamps are normalized to `config.dynamodb_timezone` (see [Time Zones](#time-zones)):

```ruby
class Order
  include Dynamoid::Document

  field :placed_at, :datetime, store_as_string: true
end

order = Order.create!(placed_at: "2026-10-11 12:00:00")

# DynamoDB item attribute:
# "placed_at": "2026-10-11T12:00:00+00:00" (String, ISO-8601)
```

> [!NOTE]
> Storing timestamps as numbers preserves nanosecond precision and allows exact numerical range queries. Storing timestamps as ISO-8601 strings provides human-readable values in external tools and the AWS Console, but string timestamps truncate fractional seconds.

#### Dates

The `:date` type manages calendar dates without time or time zone components.

On assignment, Dynamoid casts values (including `Date`, `DateTime`, `Time`, and formatted strings like `"2026-10-11"`) into `Date` via `#to_date`. In-memory attributes always return a `Date` (or `nil` if unset).

In DynamoDB, dates are stored by default as an integer count of days since the Unix epoch (January 1, 1970) in Number attributes:

```ruby
class User
  include Dynamoid::Document

  field :birth_date, :date
end

user = User.create!(birth_date: "1990-05-15")

# DynamoDB item attribute:
# "birth_date": 7439 (Number, integer days since January 1, 1970)
```

To store dates as formatted ISO-8601 strings (`"YYYY-MM-DD"`), set `store_as_string: true` on the field, or set `config.store_date_as_string = true` globally:

```ruby
class User
  include Dynamoid::Document

  field :birth_date, :date, store_as_string: true
end

user = User.create!(birth_date: "1990-05-15")

# DynamoDB item attribute:
# "birth_date": "1990-05-15" (String, ISO-8601)
```

### Collection Types

Collection types store unique scalar sets, ordered lists, and key-value maps using native DynamoDB set and document structures.

#### Sets

Sets store collections of unique scalar values.

On assignment, Dynamoid casts objects responding to `#to_set` (such as arrays) into a `Set`. When the `:of` option is omitted, elements are kept as-is:

```ruby
class User
  include Dynamoid::Document

  field :tags, :set
end

user = User.create!(tags: ["ruby", "aws", "ruby"])
user.tags # => #<Set: {"ruby", "aws"}>

# DynamoDB item attribute:
# "tags": ["ruby", "aws"] (String Set)
```

To enforce and cast element types, specify the `:of` option. Supported element types include `:string`, `:integer`, `:number`, `:date`, `:datetime`, `:serialized`, and custom types. Each element is cast to the declared type:

```ruby
class User
  include Dynamoid::Document

  field :roles, :set, of: :string
end

user = User.create!(roles: [:admin, "editor", "admin"])
user.roles # => #<Set: {"admin", "editor"}>

# DynamoDB item attribute:
# "roles": ["admin", "editor"] (String Set)
```

Element type options can also be provided using a nested Hash, where standard field type options can be specified:

```ruby
field :payloads, :set, of: { serialized: { serializer: JSON } }
```

When nested options are omitted, element type casting and storage respect global configuration options (such as `config.store_date_as_string` or `config.store_datetime_as_string`).

In DynamoDB, sets are stored as native String Set, Number Set, or Binary Set attributes. Sets carry strict database-level constraints: all elements must share the same scalar type, duplicates are ignored, and empty sets are strictly prohibited by DynamoDB. To prevent database validation errors, Dynamoid persists empty sets (`Set.new` or `[]`) as `nil`.

#### Arrays

Arrays store ordered collections of elements persisted as native DynamoDB List attributes.

On assignment, Dynamoid casts objects responding to `#to_a` into an `Array` (objects not responding to `#to_a` cast to `nil`). When the `:of` option is omitted, elements are kept as-is:

```ruby
class User
  include Dynamoid::Document

  field :preferences, :array
end

user = User.create!(preferences: ["email", "sms"])
user.preferences # => ["email", "sms"]

# DynamoDB item attribute:
# "preferences": ["email", "sms"] (List)
```

To enforce and cast element types, specify the `:of` option. Supported element types include `:string`, `:integer`, `:number`, `:date`, `:datetime`, `:serialized`, and custom types. Each element is cast to the declared type:

```ruby
class User
  include Dynamoid::Document

  field :scores, :array, of: :integer
end

user = User.create!(scores: ["10", 20.5, 30])
user.scores # => [10, 20, 30]

# DynamoDB item attribute:
# "scores": [10, 20, 30] (List of Numbers)
```

Element type options can also be provided using a nested Hash, where standard field type options can be specified:

```ruby
field :login_times, :array, of: { datetime: { store_as_string: true } }
```

When nested options are omitted, element type casting and storage respect global configuration options.

Untyped arrays also support non-scalar element types (such as nested hashes or arrays):

```ruby
user = User.create!(preferences: [
  { channel: "email", frequency: "daily" },
  { channel: "sms", frequency: "weekly" }
])

# DynamoDB item attribute:
# "preferences": [{"channel": "email", "frequency": "daily"}, {"channel": "sms", "frequency": "weekly"}] (List of Maps)

user.reload.preferences
# => [{ "channel" => "email", "frequency" => "daily" }, { "channel" => "sms", "frequency" => "weekly" }]
```

In DynamoDB, arrays are stored as native List attributes. Unlike Sets, DynamoDB Lists preserve insertion order, allow duplicate elements, and natively support empty lists (`[]`).

#### Maps

Maps store key-value dictionaries persisted as native DynamoDB Map attributes.

On assignment, Dynamoid casts objects responding to `#to_hash` or `#to_h` into a `Hash`. In-memory attributes return a `Hash` (or `nil` if unset):

```ruby
class User
  include Dynamoid::Document

  field :settings, :map
end

user = User.create!(settings: { theme: "dark", language: "en" })

# DynamoDB item attribute:
# "settings": {"theme": "dark", "language": "en"} (Map)

user.reload.settings
# => { theme: "dark", language: "en" }
```

Maps also support nested non-scalar values (such as nested hashes or arrays):

```ruby
user = User.create!(settings: {
  notifications: { email: true, sms: false }
})

# DynamoDB item attribute:
# "settings": {"notifications": {"email": true, "sms": false}} (Map)

user.reload.settings
# => { notifications: { email: true, sms: false } }
```

In DynamoDB, maps are persisted as native Map attributes with stringified keys. When items are loaded from DynamoDB, all map keys are symbolized recursively. Numbers inside maps reload as `BigDecimal` by default; set `config.convert_big_decimal = true` to convert them to `Float` values upon reload.

### Untyped Fields (`:raw`)

The `:raw` type stores arbitrary Ruby data structures directly without type casting. On assignment, Dynamoid performs no conversion, preserving the assigned object in memory as-is:

```ruby
class User
  include Dynamoid::Document

  field :metadata, :raw
end

user = User.create!(metadata: { client: "mobile", config: { retries: 3 }, tags: ["beta", 42] })

# DynamoDB item attribute:
# "metadata": {"client": "mobile", "config": {"retries": 3}, "tags": ["beta", 42]} (Map)

user.reload.metadata
# => { client: "mobile", config: { retries: 3 }, tags: ["beta", 42] }
```

In DynamoDB, `:raw` fields are stored directly as native DynamoDB types: hashes are stored as Maps, arrays as Lists, numbers (`Integer`, `Float`, `BigDecimal`) as Numbers, and IO objects (`IO`, `StringIO`) as Binary attributes, alongside strings, booleans, and sets.

When items are reloaded from DynamoDB, keys in nested hashes are symbolized automatically (matching `:map` behavior). Numbers inside nested hashes reload as `BigDecimal` by default and can be converted to `Float` via `config.convert_big_decimal = true`.

### Object Serialization (`:serialized`)

The `:serialized` type encodes arbitrary Ruby objects into a single DynamoDB String attribute using a text-based coder.

Unlike `:map` or `:raw` (which decompose Ruby structures into native DynamoDB Map and List attributes), `:serialized` packs the entire object into an encoded text string. This allows you to store Ruby objects that DynamoDB does not support natively (such as a `Range`, Structs, or complex object graphs), as well as empty collections (such as empty sets) without triggering DynamoDB collection constraints:

```ruby
class User
  include Dynamoid::Document

  field :session_data, :serialized
end

user = User.create!(session_data: { user_id: 123, role: "admin" })

# DynamoDB item attribute:
# "session_data": "---\n:user_id: 123\n:role: admin\n" (String)

user.reload.session_data
# => { user_id: 123, role: "admin" }
```

By default, objects are encoded using YAML. You can specify an alternative serializer (such as `JSON` or any object implementing `.dump` and `.load`) via the `:serializer` option:

```ruby
class User
  include Dynamoid::Document

  field :session_data, :serialized, serializer: JSON
end

user = User.create!(session_data: { user_id: 123, role: "admin" })

# DynamoDB item attribute:
# "session_data": "{\"user_id\":123,\"role\":\"admin\"}" (String)

user.reload.session_data
# => { "user_id" => 123, "role" => "admin" }
```

On assignment, Dynamoid performs no type casting, preserving the original Ruby object in memory. Assigning `nil` stores `nil` (which is omitted from DynamoDB by default).

In DynamoDB, serialized fields are persisted as native String attributes. Dynamoid deserializes YAML safely using `YAML.safe_load` with permitted classes governed by `config.yaml_permitted_classes`; set `config.use_yaml_unsafe_load = true` to enable unsafe loading for legacy compatibility (see [YAML Deserialization](#yaml-deserialization)).

### Custom Types

Custom types allow you to use dedicated Ruby classes as field types, mapping domain objects—such as Value Objects or standard library classes (`IPAddr`, `URI`)—directly to DynamoDB attributes.

Unlike scalar fields (which store disconnected primitives) or `:serialized` (which stores opaque text blobs), custom types may encapsulate business logic, validations, and calculations inside rich Ruby objects while persisting them as native DynamoDB types (such as strings, numbers, maps, or lists).

To declare a custom type, pass the Ruby class directly to `field` instead of a type name:

```ruby
class Order
  include Dynamoid::Document

  field :total, Money
end
```

Custom types can also be used in typed arrays and sets with the `:of` option:

```ruby
field :price_tiers, :array, of: Money
```

On assignment, Dynamoid performs no type casting, preserving the assigned Ruby object in memory as-is.

When persisting to DynamoDB, Dynamoid serializes the object by calling `dynamoid_dump` (either on the instance or on the field class), which must return a supported primitive Ruby type (such as a `String`, `Numeric`, `Hash`, or `Array`). When loading from DynamoDB, Dynamoid reconstructs the object by calling `.dynamoid_load` on the declared field class.

Custom types can optionally define a class method `.dynamoid_field_type` returning a Dynamoid field type (such as `:integer`, `:number`, `:datetime`, or `:date`). When this method is not implemented, Dynamoid defaults to `:string`. Dynamoid uses this when creating tables to define a table schema with the corresponding DynamoDB type whenever the field serves as a partition or sort key of a table or its index.

In practice, custom types are usually implemented using one of two patterns: as a self-serializing Value Object, or via a standalone adapter class.

#### Value Objects

A Value Object is an object whose equality is based on its value rather than its object identity. Value Objects may encapsulate validation, calculations, and formatting rules directly within their class definition.

When you control the class source code, make the class self-serializing by implementing `#dynamoid_dump` on the instance and `.dynamoid_load` on the class:

```ruby
class Money
  attr_reader :cents, :currency

  def initialize(cents, currency = "USD")
    @cents = cents.to_i
    @currency = currency.to_s
  end

  def dynamoid_dump
    "#{cents} #{currency}"
  end

  def self.dynamoid_load(string)
    cents, currency = string.to_s.split(" ")
    new(cents, currency)
  end

  def ==(other)
    other.is_a?(Money) && cents == other.cents && currency == other.currency
  end
  alias_method :eql?, :==

  def hash
    [cents, currency].hash
  end
end
```

Declare the field on your model and interact with it as a standard Ruby object:

```ruby
class Order
  include Dynamoid::Document

  field :total, Money
end

order = Order.create!(total: Money.new(4999, "USD"))

# DynamoDB item attribute:
# "total": "4999 USD" (String)

reloaded_order = Order.find(order.id)
reloaded_order.total
# => #<Money:0x... @cents=4999, @currency="USD">
reloaded_order.total.cents    # => 4999
reloaded_order.total.currency # => "USD"
```

#### Adapters

When using classes from the Ruby standard library (`IPAddr`, `URI`) or third-party gems that you cannot or prefer not to modify directly, define a standalone *Adapter* class.

An adapter implements both `.dynamoid_dump(object)` and `.dynamoid_load(serialized_value)` as class methods:

```ruby
require "ipaddr"

class IPAddrAdapter
  def self.dynamoid_dump(ip)
    ip&.to_s
  end

  def self.dynamoid_load(string)
    IPAddr.new(string) if string.present?
  end
end
```

Declare the attribute using the adapter class. Your application interacts directly with instances of the adapted class (`IPAddr`), while Dynamoid delegates persistence and reconstruction to the adapter behind the scenes:

```ruby
class RequestLog
  include Dynamoid::Document

  field :remote_ip, IPAddrAdapter
end

log = RequestLog.create!(remote_ip: IPAddr.new("192.168.1.1"))

# DynamoDB item attribute:
# "remote_ip": "192.168.1.1" (String)

reloaded_log = RequestLog.find(log.id)
reloaded_log.remote_ip
# => #<IPAddr: IPv4:192.168.1.1/...>
reloaded_log.remote_ip.ipv4? # => true
```

#### Change Detection

Dynamoid tracks changes in custom type attributes to determine which fields to update when saving. This includes detecting in-place mutations, where an object's internal state changes without reassigning the attribute (for example, calling a mutating method on a custom object rather than assigning a new instance).

To detect these changes, Dynamoid supports two comparison strategies:

* *Serialized comparison (default)* — Dynamoid serializes the attribute value and compares the serialized result against the database state. This works out of the box without requiring the custom type to implement `#==`. The trade-off is performance: serializing values whenever checking for changes (such as calling `changed?` or saving) incurs extra overhead.
* *In-memory comparison* — Dynamoid compares the Ruby objects directly in memory using `#==`, skipping serialization entirely.

To enable in-memory comparison, pass `comparable: true` in the field declaration:

```ruby
class Order
  include Dynamoid::Document

  field :total, Money, comparable: true
end
```

> [!IMPORTANT]
> Only enable `comparable: true` if the custom type implements `#==` for value equality. If the class relies on Ruby's default `Object#==` (which checks object identity), two instances with the same state will never evaluate as equal. As a result, the attribute will always appear changed, triggering unnecessary DynamoDB writes on every save.

## Type Casting

Dynamoid type casts attribute values into their declared types upon assignment while retaining uncast input for validations and form re-rendering.

Type casting runs immediately when an attribute is assigned, not when the model is saved:

```ruby
class User
  include Dynamoid::Document

  field :age, :integer
  field :active, :boolean
end

user = User.new

user.age = "35"
user.age # => 35

user.active = "false"
user.active # => false
```

Because type casting runs on assignment, in-memory model instances always hold typed values.

When validation fails or when re-rendering user input in web forms, you often need the original input string before type casting altered it. ActiveModel validations (such as `validates_numericality_of`) also inspect the raw value to detect non-numeric input rather than evaluating coerced fallbacks like `0`.

Dynamoid preserves this uncast input:

```ruby
user = User.new(age: "invalid_number")

user.age                                   # => 0
user.age_before_type_cast                  # => "invalid_number"
user.read_attribute_before_type_cast(:age) # => "invalid_number"

user.attributes_before_type_cast
# => { age: "invalid_number" }
```

## Implicit Fields

When `Dynamoid::Document` is included in a model class, it implicitly declares three standard attributes:

* `id` (`:string`) — default partition key attribute.
* `created_at` (`:datetime`) — timestamp set automatically when the item is first persisted.
* `updated_at` (`:datetime`) — timestamp refreshed automatically whenever the item is saved.

### Partition Key (`id`)

Every DynamoDB table requires a partition key. By default, Dynamoid implicitly declares an `id` field with type `:string` and generates a random UUID string on save if no explicit `id` value is provided:

```ruby
user = User.new
user.id # => nil

user.save!
user.id # => "a8f5c310-8e12-4d2b-9e45-..."
```

To customize the partition key attribute name or type, see [Partition Key](table_mapping_and_provisioning.md#partition-key) in the Table Mapping & Provisioning guide.

### Timestamps

Dynamoid maintains `created_at` and `updated_at` timestamps on every model instance. When an item is first saved, Dynamoid sets both fields to the current time (unless a value was already assigned). On subsequent updates, `updated_at` is refreshed automatically.

To disable timestamps globally across your application, configure the setting in an initializer:

```ruby
Dynamoid.configure do |config|
  config.timestamps = false
end
```

To disable timestamps for a specific model while leaving them active for the rest of the application, pass `timestamps: false` to `table`:

```ruby
class AuditLog
  include Dynamoid::Document

  table timestamps: false
end
```

When timestamps are disabled, Dynamoid does not declare `created_at` or `updated_at` fields on the model and performs no automatic timestamp tracking.

### Overriding Defaults

When you need to customize an implicit field (such as changing its type or options), redeclaring the field directly triggers a logger warning about method redefinition.

To suppress the default field declaration cleanly, pass the field names (`:id`, `:created_at`, or `:updated_at`) to `skip_generating_fields` in `table`. Unlike `timestamps: false` (which disables timestamp tracking entirely), `skip_generating_fields` only suppresses the default field declaration so you can redeclare it with custom options, while Dynamoid continues to manage the timestamp automatically on save:

```ruby
class Order
  include Dynamoid::Document

  table skip_generating_fields: [:created_at]

  field :created_at, :datetime, store_as_string: true
end
```

This option is also used when redeclaring the partition key with a non-string type (see [Non-Default Type](table_mapping_and_provisioning.md#non-default-type)).

## Storage and Serialization

Dynamoid provides options to configure how attributes are serialized and stored in DynamoDB at two levels:

1. *Field-level options* — specified directly on the `field` macro (such as `store_as_string: true` or `store_as_native_binary: true`).
2. *Global configuration defaults* — configured application-wide in an initializer (such as `config.store_datetime_as_string = true`).

Field-level declarations always take precedence over global settings. If a field-level option is omitted, Dynamoid falls back to the corresponding global configuration setting.

### Configuration Reference

The following table catalogs all configuration options that govern attribute serialization, type casting, and storage formats:

| Global Option | Default Value | Per-Field Override |
|---|---|---|
| `store_boolean_as_native` | `true` | `store_as_native_boolean` |
| `store_datetime_as_string` | `false` | `store_as_string` |
| `store_date_as_string` | `false` | `store_as_string` |
| `store_binary_as_native` | `false` | `store_as_native_binary` |
| `store_attribute_with_nil_value` | `false` | — |
| `store_empty_string_as_nil` | `true` | — |
| `convert_big_decimal` | `false` | — |
| `application_timezone` | `:utc` | — |
| `dynamodb_timezone` | `:utc` | — |
| `use_yaml_unsafe_load` | `false` | — |
| `yaml_permitted_classes` | `[Symbol, Set, Date, Time, DateTime]` | — |

### Historical Background

Several storage configuration options exist because Amazon DynamoDB's data model evolved significantly after its initial release in 2012. As DynamoDB introduced new capabilities, Dynamoid added configuration options to adopt the new database behavior while preserving backward compatibility for existing data:

* *The Original 2012 Data Model* — DynamoDB launched supporting only strings and numbers, with binary data added later that year. It had no concept of booleans, nulls, lists, or maps. Dynamoid originally stored booleans as `'t'` and `'f'` strings, and omitted or removed attributes assigned `nil`.
* *Document Types & Null Values (October 2014)* — AWS introduced native booleans, explicit nulls, lists, and maps. Dynamoid introduced `store_boolean_as_native` to support native booleans while maintaining compatibility with legacy data, and `store_attribute_with_nil_value` to optionally persist explicit null attributes.
* *Empty String Support (May 2020)* — DynamoDB originally rejected empty strings, so Dynamoid automatically converted empty strings to `nil`. After DynamoDB added support for empty strings in 2020, Dynamoid introduced `store_empty_string_as_nil` (defaulting to `true` for backward compatibility) to allow applications to persist empty strings as-is.

### Nil Attributes

When a model attribute has a `nil` value, Dynamoid can store it in DynamoDB in two ways: by omitting the attribute entirely, or by persisting an explicit `NULL` value. By default, Dynamoid omits or removes attributes with `nil` values, preserving the original DynamoDB behavior from before native `NULL` support was added.

Omitting `NULL` attributes provides two advantages:

* *Storage and throughput efficiency* — In DynamoDB, attribute names and values both contribute to item size. Storing explicit `NULL` values increases item size and consumes additional read and write throughput, whereas omitting `nil` attributes conserves capacity.
* *Index compatibility and sparse indexes* — DynamoDB index keys (partition keys and sort keys for tables and secondary indexes) only support String, Number, or Binary types; they strictly prohibit `NULL`. Persisting an explicit `NULL` to an indexed attribute causes DynamoDB to raise a `ValidationException`. Omitting `nil` attributes prevents this error automatically and enables sparse secondary indexes.

If your application or external integrations require explicit null values, enable `store_attribute_with_nil_value`:

```ruby
Dynamoid.configure do |config|
  config.store_attribute_with_nil_value = true
end
```

When enabled, attributes with `nil` values are persisted as explicit DynamoDB null (`NULL`) attributes.

### Numbers in Nested Structures

By default, numbers inside nested structures (such as `:map` and `:raw` fields) reload from DynamoDB as `BigDecimal` instances to avoid losing numeric precision:

```ruby
user = User.create!(settings: { limit: 100, ratio: 0.75 })
user.reload.settings
# => { limit: BigDecimal("100"), ratio: BigDecimal("0.75") }
```

If `BigDecimal` objects cause friction with JSON serialization or float calculations, enable `convert_big_decimal` to convert them to standard floats when loading items:

```ruby
Dynamoid.configure do |config|
  config.convert_big_decimal = true
end

user.reload.settings
# => { limit: 100.0, ratio: 0.75 }
```

### Time Zones

For `:datetime` fields, Dynamoid is time zone-aware and separates the time zone used in your application from the time zone used for database storage:

* `Dynamoid.config.application_timezone` (default `:utc`) — controls how `DateTime` instances are presented in your application (`:utc`, `:local`, or a named zone like `"America/New_York"`). In Rails applications, set this to `:local` or `Time.zone.name`.
* `Dynamoid.config.dynamodb_timezone` (default `:utc`) — controls the time zone used when writing timestamps to DynamoDB as ISO-8601 strings.

```ruby
Dynamoid.configure do |config|
  config.application_timezone = "America/New_York"
  config.dynamodb_timezone = :utc
  config.store_datetime_as_string = true
end

# Strings without an explicit offset are interpreted in application_timezone
order = Order.create!(placed_at: "2026-10-15 16:00:00")

order.placed_at
# => 2026-10-15T16:00:00-04:00

# DynamoDB item attribute:
# "placed_at": "2026-10-15T20:00:00+00:00" (normalized to UTC)

order.reload.placed_at
# => 2026-10-15T16:00:00-04:00
```

When storing timestamps as strings, Dynamoid normalizes values to `dynamodb_timezone` (UTC by default). Because ISO-8601 strings sort alphabetically, uniform normalization ensures range queries (`between`, `gt`, `lt`) and chronological sorting work reliably. (Numeric timestamps are stored as epoch seconds and are inherently UTC.)

### YAML Deserialization

When using `:serialized` without an explicit serializer, Dynamoid uses YAML for attribute encoding and decoding.

Following modern Ruby security practices, Dynamoid uses `YAML.safe_load` by default to prevent arbitrary code execution vulnerabilities. The default permitted classes are `[Symbol, Set, Date, Time, DateTime]`.

If a serialized attribute contains an unlisted class, deserialization raises a `Psych::DisallowedClass` exception. To allow additional classes, add them to `yaml_permitted_classes` in an initializer:

```ruby
Dynamoid.configure do |config|
  config.yaml_permitted_classes += [MyClass]
end
```

Alternatively, if your application runs in a trusted environment and requires unrestricted deserialization of arbitrary object graphs, enable `use_yaml_unsafe_load`:

```ruby
Dynamoid.configure do |config|
  config.use_yaml_unsafe_load = true
end
```

{{#include ../_includes/feedback.md}}
