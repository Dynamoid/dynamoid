# Dynamoid Basics

Dynamoid is an Object-Document Mapper (ODM) for Amazon DynamoDB written in Ruby. It provides a familiar, ActiveRecord-like interface for Rails and standalone Ruby applications, making DynamoDB as intuitive and productive to work with as a traditional relational database—while leveraging the horizontal scale, managed infrastructure, and performance of DynamoDB.

---

## The DynamoDB Mental Model

Before defining models, it is essential to understand how DynamoDB differs from relational databases (like PostgreSQL or MySQL):

* **NoSQL Document Storage:** In DynamoDB, each table holds *items* (records), and each item is a collection of *attributes* (fields). Items in the same table can have different attributes.
* **Primary Keys:** Every item must have a primary key that uniquely identifies it. DynamoDB supports two types of primary keys:
  * **Simple Primary Key:** A single attribute called the **Partition Key** (or Hash Key).
  * **Composite Primary Key:** A **Partition Key** combined with a **Sort Key** (or Range Key).
* **Access Patterns over Ad-Hoc Queries:** DynamoDB is designed for predictable, single-digit millisecond latency at any scale. Retrieving an item by its primary key (or querying an index) is extremely fast and efficient (a **Query**). Searching by arbitrary non-indexed attributes requires inspecting every item in the table (a **Scan**), which is slower and consumes more read capacity.
* **No Relational Joins:** DynamoDB does not perform database-level joins. Relationships in Dynamoid (like `has_many` or `belongs_to`) are resolved through foreign key references or ID collections.

---

## Defining a Model

To declare a model, create a Ruby class and include `Dynamoid::Document`:

```ruby
class User
  include Dynamoid::Document

  # Configure table settings (optional)
  table name: :users, key: :user_id

  # Declare fields and their data types
  field :name, :string
  field :email, :string
  field :age, :integer
  field :active, :boolean, default: true

  # ActiveModel validations
  validates :name, presence: true
  validates :email, format: { with: /@/ }
end
```

### Conventions & Defaults

Dynamoid follows **Convention over Configuration**:

* **Table Name:** Derived automatically from the pluralized class name (e.g., `User` &rarr; `users`). If a namespace is configured (e.g., `config.namespace = 'myapp_development'`), the table becomes `myapp_development_users`.
* **Primary Key:** By default, Dynamoid defines a partition key named `id` of type `string`. When creating new items, Dynamoid automatically assigns a UUID string if no `id` is provided.
* **Timestamps:** Dynamoid automatically declares and updates `created_at` and `updated_at` datetime attributes for every document (unless disabled globally or per-table).

---

## Basic CRUD Operations

### 1. Creating and Persisting Records

You can instantiate a document and save it in two steps, or create and save it in one step:

```ruby
# Instantiate and save
user = User.new(name: 'Alice', email: 'alice@example.com')
user.age = 30
user.save

# Or create directly
user = User.create(name: 'Bob', email: 'bob@example.com', age: 25)

# Primary key is automatically assigned if not specified
user.id # => "8b9e6f1a-7b3c-4d5e-9f0a-1b2c3d4e5f6a"
user.new_record? # => false
```

Bang methods (`save!` and `create!`) raise `Dynamoid::Errors::DocumentNotValid` if validations fail:

```ruby
user = User.create!(name: '') # Raises Dynamoid::Errors::DocumentNotValid
```

### 2. Reading and Finding Records

You can retrieve records by their primary key or query them using criteria:

```ruby
# Find by primary key (partition key)
user = User.find(user_id)

# Find by criteria
active_users = User.where(active: true).all
adult = User.where('age.gte': 18).first

# Find or initialize
user = User.find_by_email('alice@example.com')
```

### 3. Updating Records

Updating attributes runs validations and callbacks:

```ruby
# Update attributes on an instance
user.update(age: 31)

# Or modify attributes directly and save
user.age = 31
user.save

# Update single attribute
user.update_attribute(:active, false)
```

### 4. Deleting Records

```ruby
# Destroy an individual record (runs callbacks)
user.destroy
user.destroyed? # => true

# Delete all matching records in batch (efficient, skips callbacks)
User.where(active: false).delete_all
```

---

## Validations

Dynamoid bakes in `ActiveModel::Validations`, giving you the exact same validation DSL familiar from Rails:

```ruby
class Product
  include Dynamoid::Document

  field :sku, :string
  field :price, :number
  field :inventory_count, :integer

  validates :sku, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :inventory_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

### Checking Validity & Errors

```ruby
product = Product.new(price: -5)
product.valid? # => false
product.errors[:sku]   # => ["can't be blank"]
product.errors[:price] # => ["must be greater than 0"]
```

### Bypassing Validations

If you need to bypass validation when saving, pass `validate: false`:

```ruby
product.save(validate: false)
```

---

## Lifecycle Callbacks

Dynamoid integrates `ActiveModel::Callbacks`. The following standard lifecycle callbacks are supported:

* **Save:** `before_save`, `around_save`, `after_save`
* **Create:** `before_create`, `around_create`, `after_create`
* **Update:** `before_update`, `around_update`, `after_update`
* **Destroy:** `before_destroy`, `around_destroy`, `after_destroy`
* **Validation:** `before_validation`, `after_validation`
* **Touch:** `after_touch`
* **Initialization & Loading:** `after_initialize`, `after_find`

### Example

```ruby
class Order
  include Dynamoid::Document

  field :total, :number
  field :reference_number, :string

  before_validation :generate_reference_number, on: :create
  before_save :calculate_totals
  after_create :notify_warehouse
  after_destroy :audit_log_deletion

  private

  def generate_reference_number
    self.reference_number ||= SecureRandom.hex(8).upcase
  end

  def calculate_totals
    # ...
  end

  def notify_warehouse
    # ...
  end

  def audit_log_deletion
    # ...
  end
end
```

---

## Dirty Attribute Tracking

Dynamoid tracks attribute modifications using `ActiveModel::Dirty`:

```ruby
user = User.find(id)
user.name_changed? # => false

user.name = 'Alexander'
user.name_changed? # => true
user.name_was      # => "Alex"
user.changes       # => { "name" => ["Alex", "Alexander"] }

user.save
user.name_changed? # => false
```

> **Note on In-Place Mutation:** As with ActiveModel in Rails, modifying an object in-place (such as pushing onto an array `user.tags << 'ruby'` or mutating a hash) is not automatically detected by dirty tracking. You should either reassign the attribute (`user.tags = user.tags + ['ruby']`) or explicitly call `user.tags_will_change!`.

---

## Next Steps

Now that you understand the basic document model and lifecycle:

* Configure table names, partition keys, and throughput in [Tables & Primary Keys](setup/tables_and_keys.md).
* Explore data types, collections, and custom serializers in [Fields & Data Types](setup/fields_and_types.md).
* Speed up searches on non-key attributes in [Secondary Indexes](setup/secondary_indexes.md).
* Build relationships between models in [Associations](setup/associations.md).
* Learn query chaining, scans vs. queries, and pagination in [Query Interface](usage/query_interface.md).
