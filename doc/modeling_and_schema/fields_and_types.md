# Fields & Data Types

In Dynamoid, all fields on a model must be explicitly defined using the `field` class method. If DynamoDB contains attributes that are not declared on your model, Dynamoid will ignore them when loading items into memory.

```ruby
class User
  include Dynamoid::Document

  field :name, :string
  field :age, :integer
  field :active, :boolean, default: true
end
```

## Supported Data Types

Dynamoid supports all native DynamoDB attribute types, as well as high-level Ruby types with automatic serialization and type coercion.

| Dynamoid Type | DynamoDB Underlying Type | Description |
|---|---|---|
| `:string` (default) | String (`S`) | UTF-8 text strings. |
| `:integer` | Number (`N`) | Whole numbers (coerced to Ruby `Integer`). |
| `:number` | Number (`N`) | Floating point and arbitrary precision numbers (`BigDecimal` / `Float`). |
| `:boolean` | Boolean (`BOOL`) or String (`S`) | Boolean values (`true`/`false`). |
| `:datetime` | Number (`N`) or String (`S`) | Timestamp with millisecond precision. |
| `:date` | Number (`N`) or String (`S`) | Calendar date. |
| `:set` | String Set (`SS`), Number Set (`NS`), Binary Set (`BS`) | Unique collection of homogeneous elements. |
| `:array` | List (`L`) | Ordered list of heterogeneous or homogeneous elements. |
| `:map` | Map (`M`) | Nested key-value dictionary (Ruby `Hash`). |
| `:binary` | Binary (`B`) or String (`S`) | Raw bytes or Base64 encoded binary data. |
| `:raw` | Any (`S`, `N`, `M`, `L`, etc.) | Stores raw Ruby objects without type casting. |
| `:serialized` | String (`S`) | Serializes Ruby objects to string (default: YAML or custom serializer). |
| Custom Class | String (`S`) or Number (`N`) | Arbitrary Ruby class implementing serialization methods. |

## Detailed Type Configurations

### 1. Boolean Fields

By default, boolean fields are stored as native DynamoDB boolean values (`true`/`false`). If you need backward compatibility with legacy string-based booleans (`'t'` / `'f'`), use `store_as_native_boolean: false`:

```ruby
class Document
  include Dynamoid::Document

  field :active, :boolean, store_as_native_boolean: true # default
  field :archived, :boolean, store_as_native_boolean: false
end
```

### 2. Date and DateTime Fields

* **Dates:** By default, date fields are persisted as an integer representing days since January 1, 1970 (UNIX epoch).
* **DateTimes:** By default, datetime fields are persisted as numeric UNIX timestamps with millisecond precision.

To store them as human-readable ISO-8601 formatted strings in DynamoDB, specify `store_as_string: true`:

```ruby
class Article
  include Dynamoid::Document

  field :published_on, :date, store_as_string: true
  field :published_at, :datetime, store_as_string: true
end
```

> **Warning for Sort Keys:** Datetime fields in numeric format lose sub-millisecond precision when stored in DynamoDB. When using a `datetime` attribute as a sort key (`range`), either set `store_as_string: true` or truncate microseconds before saving.

### 3. Sets

Dynamoid's `:set` maps directly to DynamoDB's native Set attribute types. DynamoDB requires that:
1. All elements in a Set must be of the **same scalar type**.
2. Sets cannot contain empty strings.

Specify the element type using the `of:` option:

```ruby
class Document
  include Dynamoid::Document

  field :tags, :set, of: :string
  field :lucky_numbers, :set, of: :integer
  field :timestamps, :set, of: { datetime: { store_as_string: true } }
end
```

Supported element types for sets: `:string`, `:integer`, `:number`, `:date`, `:datetime`, and `:serialized`. Dynamoid automatically removes empty strings before saving.

### 4. Arrays (Lists) and Maps

* **Array:** Mapped to DynamoDB's native `List` (`L`) type. Unlike Sets, arrays can contain elements of mixed types and preserve insertion order. You can optionally enforce homogeneous types via `of:`:

```ruby
class Report
  include Dynamoid::Document

  field :ratings, :array, of: :number
  field :metadata, :map # Stores a nested Ruby Hash
end
```

### 5. Binary Fields

By default, binary fields are stored as Base64-encoded strings. To use native DynamoDB binary data, specify `store_binary_as_native: true`:

```ruby
class Asset
  include Dynamoid::Document

  field :thumbnail, :binary, store_binary_as_native: true
end
```

### 6. Serialized Fields

To serialize complex Ruby objects into a string attribute:

```ruby
class Preferences
  include Dynamoid::Document

  # Defaults to YAML serialization
  field :settings, :serialized

  # Custom serializer (any object responding to #dump and #load, such as JSON)
  field :ui_state, :serialized, serializer: JSON
end
```

## Automatic Fields (Magic Fields)

Every `Dynamoid::Document` automatically defines three implicit fields:

* *id* (`:string`) — the default partition key attribute.
* *created_at* (`:datetime`) — set automatically when the item is first persisted.
* *updated_at* (`:datetime`) — updated automatically whenever changes are saved.

### Disabling Timestamps

You can disable automatic timestamp management globally across all models in an initializer:

```ruby
Dynamoid.configure do |config|
  config.timestamps = false
end
```

To disable timestamps for a specific model while leaving them enabled globally, use the `timestamps: false` option in the `table` declaration:

```ruby
class ReadOnlyEvent
  include Dynamoid::Document

  table timestamps: false

  field :payload, :string
end
```

When `timestamps: false` is configured, Dynamoid omits the automatic `created_at` and `updated_at` fields and does not update them during persistence.

### Suppressing Generated Fields

When `Dynamoid::Document` is included, it automatically declares `id`, `created_at`, and `updated_at`, defining their reader, writer, and predicate methods.

If your model or legacy DynamoDB table should not declare these default fields or generate their accessors, specify them via `:skip_generating_fields` in `table`:

```ruby
class ExternalItem
  include Dynamoid::Document

  table skip_generating_fields: %i[id created_at updated_at]
end
```

Alternatively, you can remove individual declared or default fields programmatically using `remove_field`:

```ruby
class CustomRecord
  include Dynamoid::Document

  remove_field :created_at
end
```

## Field Options

### Default Values

You can provide a static default value or a callable (lambda / proc) that is re-evaluated each time a new model instance is initialized:

```ruby
class User
  include Dynamoid::Document

  field :status, :string, default: 'pending'
  field :view_count, :integer, default: 0
  field :joined_at, :datetime, default: -> { Time.now }
end
```

### Aliases

If your DynamoDB table uses camelCase or uppercase attribute names, you can define a Ruby-friendly snake_case alias:

```ruby
class User
  include Dynamoid::Document

  field :firstName, :string, alias: :first_name
end

user = User.new(first_name: 'Michael')
user.first_name # => "Michael"
user.firstName  # => "Michael"
```

Dynamoid automatically defines getter, setter, predicate, and `_before_type_cast` methods for both the original attribute name and the alias.

## Type Casting

Values assigned to attributes are automatically coerced to the declared field type:

```ruby
# Boolean coercion
user.active = 'false' # => false
user.active = 'off'   # => false
user.active = 1       # => true

# Integer coercion
user.age = '25'  # => 25 (Integer)
user.age = 25.9  # => 25 (Integer)

# DateTime coercion (uses application time zone if not specified)
user.created_at = '2026-10-01 12:00:00'
```

### Accessing Values Before Type Casting

To inspect the raw, unconverted value assigned to an attribute:

```ruby
user = User.new(age: '42')

user.age                  # => 42 (Integer)
user.age_before_type_cast # => "42" (String)

# Get all raw assigned values
user.attributes_before_type_cast # => { age: "42" }
```

## Generated Accessor Methods

For every declared field `name`, Dynamoid dynamically defines four methods on your model:

* **Getter:** `user.name` &rarr; Returns the type-casted value.
* **Setter:** `user.name = 'value'` &rarr; Assigns and casts the value, marking the attribute as dirty.
* **Presence Query:** `user.name?` &rarr; Returns `true` if the attribute is present and not blank.
* **Raw Reader:** `user.name_before_type_cast` &rarr; Returns the value before type coercion.

## Custom Types

You can use custom Ruby classes as field types by implementing `.dynamoid_load` and `#dynamoid_dump`:

```ruby
class Money
  attr_reader :cents

  def initialize(cents)
    @cents = cents
  end

  def dynamoid_dump
    cents.to_s
  end

  def self.dynamoid_load(serialized_str)
    new(serialized_str.to_i)
  end

  def ==(other)
    other.is_a?(Money) && cents == other.cents
  end
end

class Invoice
  include Dynamoid::Document

  field :total, Money, comparable: true
end
```

### Key Considerations for Custom Types:
* **Storage Type:** By default, custom types are stored as strings. To store them as numbers, define a class method `.dynamoid_field_type` returning `:number`.
* **Change Detection:** By default, Dynamoid checks for changes by comparing dumped string representations. If your class implements `#==`, specify `comparable: true` to compare instances directly.
* **Third-Party Adapters:** If you cannot modify a third-party class to add `#dynamoid_dump`, define a standalone adapter class providing `.dynamoid_load` and `.dynamoid_dump(object)` methods.
