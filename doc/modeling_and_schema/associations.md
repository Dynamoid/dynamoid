# Associations

An *association* is a connection between two Dynamoid models. Most applications work with domain entities that relate to one another: an author writes many books, a user has one profile, or students enroll in multiple courses.

Dynamoid provides class-level association macros—modeled after Rails `ActiveRecord`—to declare *one-to-one*, *one-to-many*, and *many-to-many* relationships between models. Declaring an association tells Dynamoid how two models are connected, automatically generates the underlying foreign key fields, and adds convenience methods to link, query, and delete related models.

> [!IMPORTANT]
> Associations are only supported for models with a simple primary key (partition key only). Models that declare a sort key cannot declare associations or be referenced by associations on other models.

## Associations Overview

### Without Associations

To see why associations are useful, consider an application with `Author` and `Book` models where each author can have many books. Without associations, you have to declare foreign key fields and coordinate every cross-model operation by hand:

```ruby
class Author
  include Dynamoid::Document

  field :name
end

class Book
  include Dynamoid::Document

  field :title
  field :author_id
end
```

To create a book for an existing author, you must manually pass the author's partition key (`author.id`):

```ruby
author = Author.create(name: 'Ursula K. Le Guin')
book = Book.create(title: 'A Wizard of Earthsea', author_id: author.id)
```

To retrieve all books written by that author, you have to construct an explicit query using `author.id`:

```ruby
books = Book.where(author_id: author.id).all
```

And if you want to delete an author along with all of their books, you must manually query the books, iterate through them to destroy each one, and then destroy the author:

```ruby
books = Book.where(author_id: author.id).all
books.each do |book|
  book.destroy
end
author.destroy
```

### Using Associations

With Dynamoid associations, you express the relationship between `Author` and `Book` declaratively on the model classes:

```ruby
class Author
  include Dynamoid::Document

  has_many :books

  field :name
end

class Book
  include Dynamoid::Document

  belongs_to :author

  field :title
end
```

With this declaration in place, creating a new book for an author no longer requires passing foreign keys manually:

```ruby
author = Author.create(name: 'Ursula K. Le Guin')
book = author.books.create(title: 'A Wizard of Earthsea')
```

Navigating between related models in either direction uses natural reader methods:

```ruby
author.books.all # => [#<Book id: "...", title: "A Wizard of Earthsea", ...>]
book.author      # => #<Author id: "...", name: "Ursula K. Le Guin", ...>
```

And destroying all of an author's books is reduced to a single method call on the collection:

```ruby
author.books.destroy_all
author.destroy
```

> [!IMPORTANT]
> Unlike `ActiveRecord`—where assigning an association only updates an in-memory attribute until `save` is called—modifying an association in Dynamoid immediately saves the changes to DynamoDB. Because association mutation methods (`=`, `<<`, `create`, `delete`, etc.) persist changes by calling `update_attribute`, any unsaved attribute changes pending on either model instance will also be written to DynamoDB.

## Types of Associations

Dynamoid supports four types of associations:

* [`belongs_to`](#belongs_to)
* [`has_one`](#has_one)
* [`has_many`](#has_many)
* [`has_and_belongs_to_many`](#has_and_belongs_to_many)

### `belongs_to`

A `belongs_to` association sets up a connection with another model such that each instance of the declaring model belongs to one instance of the target model. For example, if your application includes authors and books, and each book is written by a single author, declare `belongs_to :author` on the `Book` model:

```ruby
class Book
  include Dynamoid::Document

  belongs_to :author

  field :title
end
```

Unlike relational databases that require migrations to add foreign key columns, `belongs_to` automatically declares the underlying foreign key field on the model—you do not need to declare a separate `field` for it.

> [!NOTE]
> `belongs_to` associations must use a singular name. Because Dynamoid infers the target class name by classifying the association name, declaring `belongs_to :authors` would look for an `Authors` class instead of `Author`.

`belongs_to` can be used in either a *one-to-one* relationship (paired with `has_one` on the other model) or a *one-to-many* relationship (paired with `has_many` on the other model). When used alone, `belongs_to` creates a one-directional relationship: each `Book` knows its `Author`, but `Author` instances do not know about their books. To set up a bidirectional association, combine `belongs_to` with `has_one` or `has_many` on the `Author` model.

#### Methods Added by `belongs_to`

When you declare a `belongs_to` association, the declaring class automatically gains two methods related to the association:

* `<association>`
* `<association>=(model)`

In both methods, `<association>` is replaced with the symbol passed as the first argument to `belongs_to`. For `belongs_to :author`, a `Book` instance gains `book.author` and `book.author=`.

Calling `book.author` returns an *association proxy* rather than the `Author` instance directly. The proxy exposes the following methods to manage the association:

* `<association>.create(attributes)`
* `<association>.create!(attributes)`
* `<association>.delete`
* `<association>.target`
* `<association>.loaded?`
* `<association>.reset`

Returning a proxy allows you to call methods like `book.author.create` or `book.author.delete` even when no author is currently linked. On first access, the proxy lazily loads the associated `Author` model and forwards all other method calls directly to it.

#### Reading the Association

The `<association>` method returns the associated model, or `nil` if no associated model is found:

```ruby
author = book.author
```

Because the proxy forwards method calls to the target model, you can call `Author` methods directly on `book.author`:

```ruby
book.author.update_attribute(:name, 'Ursula K. Le Guin')
```

If the associated model has already been retrieved from DynamoDB, the cached version is returned. To clear the cached model so the next access fetches it from DynamoDB again, call `reset`:

```ruby
book.author.reset
```

#### Assigning and Creating

The `<association>=` method links an existing model to this model:

```ruby
book.author = author
```

The `<association>.create` method instantiates a new model of the target class, saves it to DynamoDB, and links it to this model:

```ruby
author = book.author.create(name: 'Ursula K. Le Guin')
```

The `<association>.create!` method does the same, but raises a validation error if the target model is invalid:

```ruby
author = book.author.create!(name: 'Ursula K. Le Guin')
```

#### Removing the Association

To unlink the associated model without deleting its item from DynamoDB, call `delete` on the association proxy or assign `nil`:

```ruby
book.author.delete
book.author = nil
```

#### Checking Presence

You can check whether an associated model exists using `nil?`, `blank?`, or `present?`:

```ruby
book.author.nil?     # => true
book.author.blank?   # => true
book.author.present? # => false
```

### `has_one`

A `has_one` association sets up a *one-to-one* relationship with another model, where each instance of the declaring model is associated with at most one instance of the target model. For example, if each user in your application has a single profile, declare `has_one :profile` on the `User` model:

```ruby
class User
  include Dynamoid::Document

  has_one :profile

  field :email
end
```

> [!NOTE]
> `has_one` associations must use a singular name. Because Dynamoid infers the target class name by classifying the association name, declaring `has_one :profiles` would look for a `Profiles` class instead of `Profile`.

When used alone, `has_one` creates a one-directional relationship: each `User` knows its `Profile`, but `Profile` instances do not know about their user. To set up a bidirectional association, combine `has_one` with `belongs_to` on the `Profile` model.

#### Methods Added by `has_one`

When you declare a `has_one` association, the declaring class automatically gains two methods related to the association:

* `<association>`
* `<association>=(model)`

In both methods, `<association>` is replaced with the symbol passed as the first argument to `has_one`. For `has_one :profile`, a `User` instance gains `user.profile` and `user.profile=`.

Calling `user.profile` returns an *association proxy* rather than the `Profile` instance directly. The proxy exposes the following methods to manage the association:

* `<association>.create(attributes)`
* `<association>.create!(attributes)`
* `<association>.delete`
* `<association>.target`
* `<association>.loaded?`
* `<association>.reset`

Returning a proxy allows you to call methods like `user.profile.create` or `user.profile.delete` even when no profile is currently linked. On first access, the proxy lazily loads the associated `Profile` model and forwards all other method calls directly to it.

#### Reading the Association

The `<association>` method returns the associated model, or `nil` if no associated model is found:

```ruby
profile = user.profile
```

Because the proxy forwards method calls to the target model, you can call `Profile` methods directly on `user.profile`:

```ruby
user.profile.update_attribute(:bio, 'Mathematician')
```

If the associated model has already been retrieved from DynamoDB, the cached version is returned. To clear the cached model so the next access fetches it from DynamoDB again, call `reset`:

```ruby
user.profile.reset
```

#### Assigning and Creating

The `<association>=` method links an existing model to this model:

```ruby
user.profile = profile
```

The `<association>.create` method instantiates a new model of the target class, saves it to DynamoDB, and links it to this model:

```ruby
profile = user.profile.create(bio: 'Mathematician')
```

The `<association>.create!` method does the same, but raises a validation error if the target model is invalid:

```ruby
profile = user.profile.create!(bio: 'Mathematician')
```

#### Removing the Association

To unlink the associated model without deleting its item from DynamoDB, call `delete` on the association proxy or assign `nil`:

```ruby
user.profile.delete
user.profile = nil
```

#### Checking Presence

You can check whether an associated model exists using `nil?`, `blank?`, or `present?`:

```ruby
user.profile.nil?     # => true
user.profile.blank?   # => true
user.profile.present? # => false
```

### `has_many`

A `has_many` association sets up a *one-to-many* connection with other models, where each instance of the declaring model is associated with zero or more instances of the target model. For example, if an author can have many books, declare `has_many :books` on the `Author` model:

```ruby
class Author
  include Dynamoid::Document

  has_many :books

  field :name
end
```

> [!NOTE]
> `has_many` associations must use a plural name. Dynamoid infers the target class name by singularizing and classifying the association name, so `:books` resolves to `Book`.

When used alone, `has_many` creates a one-directional relationship: each `Author` knows its books, but `Book` instances do not know about their author. To set up a bidirectional association, combine `has_many` with `belongs_to` on the `Book` model.

#### Methods Added by `has_many`

When you declare a `has_many` association, the declaring class automatically gains two methods related to the association:

* `<association>`
* `<association>=(models)`

In both methods, `<association>` is replaced with the symbol passed as the first argument to `has_many`. For `has_many :books`, an `Author` instance gains `author.books` and `author.books=`.

Calling `author.books` returns an *association proxy* rather than an `Array` directly. The proxy includes `Enumerable` and exposes the following methods to manage the collection:

* `<association>.all`
* `<association> << model`
* `<association>.create(attributes)`
* `<association>.create!(attributes)`
* `<association>.delete(model)`
* `<association>.delete_all`
* `<association>.destroy_all`
* `<association>.target`
* `<association>.loaded?`
* `<association>.reset`

On first access, the proxy lazily loads the associated `Book` models and forwards all other method calls directly to the underlying `Array`.

#### Reading the Association

The `<association>.all` method returns an array of all associated models, or an empty array (`[]`) if none are linked:

```ruby
books = author.books.all
```

Because the proxy includes `Enumerable` and forwards method calls to the underlying `Array`, you can call `Array` and `Enumerable` methods directly on `author.books`:

```ruby
first_book = author.books.first
titles = author.books.map(&:title)
```

If the associated models have already been retrieved from DynamoDB, the cached collection is returned. To clear the cached collection so the next access fetches the models from DynamoDB again, call `reset`:

```ruby
author.books.reset
```

#### Assigning and Creating

The `<association> <<` method appends an existing model (or an array of models) to the collection while preserving existing links:

```ruby
author.books << book
author.books << [book1, book2]
```

The `<association>=` method replaces the entire collection with the given model or array of models, unlinking any previously associated models:

```ruby
author.books = [book1, book2]
```

The `<association>.create` method instantiates a new model of the target class, saves it to DynamoDB, and adds it to the collection:

```ruby
book = author.books.create(title: 'A Wizard of Earthsea')
```

The `<association>.create!` method does the same, but raises a validation error if the target model is invalid:

```ruby
book = author.books.create!(title: 'A Wizard of Earthsea')
```

#### Removing the Association

To unlink a specific model (or an array of models) from the collection without deleting its item from DynamoDB, call `delete`:

```ruby
author.books.delete(book)
```

To unlink all associated models without deleting their items from DynamoDB, assign `[]` or `nil`:

```ruby
author.books = []
author.books = nil
```

To unlink all associated models and delete their items from DynamoDB without running callbacks, call `delete_all`:

```ruby
author.books.delete_all
```

To unlink all associated models and destroy their items in DynamoDB (running `destroy` callbacks on each target model), call `destroy_all`:

```ruby
author.books.destroy_all
```

#### Checking Presence

You can check whether the collection has any associated models or contains a specific model using `empty?`, `blank?`, `present?`, or `include?`:

```ruby
author.books.empty?         # => true
author.books.blank?         # => true
author.books.present?       # => false
author.books.include?(book) # => false
```

### `has_and_belongs_to_many`

A `has_and_belongs_to_many` association sets up a direct *many-to-many* connection with other models, where each instance of the declaring model is associated with zero or more instances of the target model, and vice versa. For example, if students enroll in multiple courses and each course has multiple students, declare `has_and_belongs_to_many :courses` on the `Student` model:

```ruby
class Student
  include Dynamoid::Document

  has_and_belongs_to_many :courses

  field :name
end
```

Unlike relational databases that require an intermediate join table to represent *many-to-many* relationships, `has_and_belongs_to_many` does not require a join table or join model.

> [!NOTE]
> `has_and_belongs_to_many` associations must use a plural name. Dynamoid infers the target class name by singularizing and classifying the association name, so `:courses` resolves to `Course`.

When used alone, `has_and_belongs_to_many` creates a one-directional relationship: each `Student` knows its courses, but `Course` instances do not know about their students. To set up a bidirectional association, declare `has_and_belongs_to_many :students` on the `Course` model as well.

#### Methods Added by `has_and_belongs_to_many`

When you declare a `has_and_belongs_to_many` association, the declaring class automatically gains two methods related to the association:

* `<association>`
* `<association>=(models)`

In both methods, `<association>` is replaced with the symbol passed as the first argument to `has_and_belongs_to_many`. For `has_and_belongs_to_many :courses`, a `Student` instance gains `student.courses` and `student.courses=`.

Calling `student.courses` returns an *association proxy* rather than an `Array` directly. The proxy includes `Enumerable` and exposes the following methods to manage the collection:

* `<association>.all`
* `<association> << model`
* `<association>.create(attributes)`
* `<association>.create!(attributes)`
* `<association>.delete(model)`
* `<association>.delete_all`
* `<association>.destroy_all`
* `<association>.target`
* `<association>.loaded?`
* `<association>.reset`

On first access, the proxy lazily loads the associated `Course` models and forwards all other method calls directly to the underlying `Array`.

#### Reading the Association

The `<association>.all` method returns an array of all associated models, or an empty array (`[]`) if none are linked:

```ruby
courses = student.courses.all
```

Because the proxy includes `Enumerable` and forwards method calls to the underlying `Array`, you can call `Array` and `Enumerable` methods directly on `student.courses`:

```ruby
first_course = student.courses.first
titles = student.courses.map(&:title)
```

If the associated models have already been retrieved from DynamoDB, the cached collection is returned. To clear the cached collection so the next access fetches the models from DynamoDB again, call `reset`:

```ruby
student.courses.reset
```

#### Assigning and Creating

The `<association> <<` method appends an existing model (or an array of models) to the collection while preserving existing links:

```ruby
student.courses << course
student.courses << [course1, course2]
```

The `<association>=` method replaces the entire collection with the given model or array of models, unlinking any previously associated models:

```ruby
student.courses = [course1, course2]
```

The `<association>.create` method instantiates a new model of the target class, saves it to DynamoDB, and adds it to the collection:

```ruby
course = student.courses.create(title: 'Distributed Systems')
```

The `<association>.create!` method does the same, but raises a validation error if the target model is invalid:

```ruby
course = student.courses.create!(title: 'Distributed Systems')
```

#### Removing the Association

To unlink a specific model (or an array of models) from the collection without deleting its item from DynamoDB, call `delete`:

```ruby
student.courses.delete(course)
```

To unlink all associated models without deleting their items from DynamoDB, assign `[]` or `nil`:

```ruby
student.courses = []
student.courses = nil
```

To unlink all associated models and delete their items from DynamoDB without running callbacks, call `delete_all`:

```ruby
student.courses.delete_all
```

To unlink all associated models and destroy their items in DynamoDB (running `destroy` callbacks on each target model), call `destroy_all`:

```ruby
student.courses.destroy_all
```

#### Checking Presence

You can check whether the collection has any associated models or contains a specific model using `empty?`, `blank?`, `present?`, or `include?`:

```ruby
student.courses.empty?           # => true
student.courses.blank?           # => true
student.courses.present?         # => false
student.courses.include?(course) # => false
```

## Association Options

While default conventions infer the target class and corresponding association names automatically, association macros accept options to customize target classes, inverse relationships, and foreign key storage:

| Option | Supported Macros | Description |
| --- | --- | --- |
| `:class_name` | All | Specifies the target class name as a String |
| `:class` | All | Specifies the target class constant directly |
| `:inverse_of` | All | Specifies the name of the corresponding association on the target class |
| `:foreign_key` | `belongs_to` | Stores the target partition key in a scalar field instead of a Set |

### `:class_name` or `:class`

By default, Dynamoid infers the target class from the association name—e.g. `:author` to `Author`. If an association uses a custom name, specify the target class explicitly using `:class_name` as a string or `:class` as a class constant:

```ruby
class Book
  include Dynamoid::Document

  belongs_to :writer, class_name: 'Author'

  field :title
end
```

Specifying the target class as a `String` via `:class_name` is generally recommended because it defers constant resolution until the association is first accessed. Passing a class constant directly (`class: Author`) resolves the constant immediately while the class definition is evaluated, which can trigger circular autoloading issues if both models reference each other during boot.

### `:inverse_of`

Dynamoid synchronizes bidirectional associations by inferring the corresponding association name from the declaring model's class name—e.g. `Author` looks for an `:author` association on `Book`.

When an association uses a custom name that cannot be inferred automatically, specify `:inverse_of` so Dynamoid knows which matching association to update:

```ruby
class Author
  include Dynamoid::Document

  has_many :publications, class_name: 'Book', inverse_of: :writer

  field :name
end

class Book
  include Dynamoid::Document

  belongs_to :writer, class_name: 'Author', inverse_of: :publications

  field :title
end

author = Author.create(name: 'Ursula K. Le Guin')
book = Book.create(title: 'A Wizard of Earthsea')

book.writer = author
author.publications.include?(book) # => true
```

### `:foreign_key`

By default, `belongs_to :author` automatically names and declares the foreign key field. Pass the `:foreign_key` option to set the attribute name directly and store the key as a scalar value:

```ruby
class Book
  include Dynamoid::Document

  belongs_to :author, foreign_key: :author_id

  field :title
end

author = Author.create(name: 'Ursula K. Le Guin')
book = Book.create(title: 'A Wizard of Earthsea')
book.author = author

book.author_id # => "a8f5c3..."
book.author    # => #<Author id: "a8f5c3...", name: "Ursula K. Le Guin", ...>
```

Passing `:foreign_key` configures two behaviors:

* Declares a field with the specified name (avoiding the need to declare `field :author_id` separately).
* Automatically sets the field type to match the partition key type of the target model (e.g. `:string` or `:integer`).

> [!TIP]
> Dynamoid does not store foreign keys as scalar values by default (for details, see [How Associations Are Stored](#how-associations-are-stored)). Because DynamoDB secondary indexes require scalar attributes, use `foreign_key:` on `belongs_to` whenever you plan to declare a [Global or Local Secondary Index](table_mapping_and_provisioning.md#secondary-indexes) on the foreign key attribute.

The `:foreign_key` option is only supported on `belongs_to`. Because Dynamoid inspects the target model's partition key type when evaluating the declaration, the target class must be defined or autoloadable when `belongs_to ..., foreign_key: ...` runs.

## Tips and Warnings

### Bidirectional Synchronization

When you declare an association on only one model, the relationship is one-directional. For example, if `Book` declares `belongs_to :author` but `Author` does not declare `has_many :books`, you can access `book.author`, but `Author` instances have no `author.books` method.

When you declare corresponding associations on both models—such as `has_many :books` on `Author` and `belongs_to :author` on `Book`—Dynamoid automatically keeps both sides synchronized whenever you link or unlink models from either side:

```ruby
class Author
  include Dynamoid::Document

  has_many :books

  field :name
end

class Book
  include Dynamoid::Document

  belongs_to :author

  field :title
end
```

Assigning the association on `book` automatically adds `book` to `author.books`:

```ruby
author = Author.create(name: 'Ursula K. Le Guin')
book = Book.create(title: 'A Wizard of Earthsea')

book.author = author
author.books.include?(book) # => true
```

Likewise, adding or removing `book` through `author.books` automatically updates `book.author`:

```ruby
author.books.delete(book)
book.reload.author # => nil
```

The same bidirectional synchronization applies to `has_one` paired with `belongs_to`, and to `has_and_belongs_to_many` declared on both models.

### Validating Associations

Unlike Rails `ActiveRecord` and `Mongoid`—where `belongs_to` requires the associated model to be present by default unless `optional: true` is specified—all associations in Dynamoid (including `belongs_to`) are optional by default.

To require that an association is present before saving, add a standard `ActiveModel` presence validation on the association name:

```ruby
class Book
  include Dynamoid::Document

  belongs_to :author

  field :title

  validates :author, presence: true
end
```

### Deletion and Disassociation

When you delete a model instance with `#delete` or `#destroy`, Dynamoid automatically iterates over its declared associations and removes its partition key from all linked models in DynamoDB:

```ruby
author = Author.create(name: 'Ursula K. Le Guin')
book = author.books.create(title: 'A Wizard of Earthsea')

book.destroy

author.reload.books.empty? # => true
```

Class-level deletion (`Book.delete(book.id)`) deletes the item directly by key without instantiating the model, so it does not update references on linked models. If a referenced item no longer exists in DynamoDB, accessing a `belongs_to` or `has_one` association returns `nil`, and `has_many` or `has_and_belongs_to_many` silently omits the missing item rather than raising `Dynamoid::Errors::RecordNotFound`.

### Caching and Reloading

While calling `reset` on an association proxy (`book.author.reset` or `author.books.reset`) clears the cached target for that single association, calling `reload` on the parent model refreshes the model's attributes from DynamoDB and resets all of its cached associations at once:

```ruby
author.books.all # Loads books from DynamoDB and caches them
author.reload    # Reloads author and resets all cached associations
author.books.all # Fetches books from DynamoDB again
```

Modifying the underlying foreign key attribute directly via `write_attribute` or `[]=` (for example, `author[:books_ids] = ...`) also resets the cached association.

### Querying and Filtering with Secondary Indexes

Use associations for bounded relationships—such as a user's profile, an author's books, or a student's courses—where loading the entire collection into memory is fast and convenient.

When you need to filter related models at the database level, or when modeling high-cardinality relationships (such as a customer with thousands of orders), avoid `has_many`. Instead, declare a [Global Secondary Index](table_mapping_and_provisioning.md#global-secondary-indexes) on the foreign key and query the target table directly via the [Query Interface](../working_with_data/query_interface.md):

```ruby
class Book
  include Dynamoid::Document

  belongs_to :author, foreign_key: :author_id

  field :title
  field :published_at, :datetime

  global_secondary_index hash_key: :author_id, range_key: :published_at
end

# Query an author's books with range key conditions via the GSI
Book.where(author_id: author.id, 'published_at.gt': 1.year.ago).all
```

## How Associations Are Stored

When designing associations in Dynamoid, an intentional decision was made that fetching associated models by foreign keys would not rely on or require Secondary Indexes. In DynamoDB, looking up items by an unindexed foreign key requires an expensive full-table scan, while Global Secondary Indexes demand careful capacity provisioning, add storage and write costs, and introduce operational overhead.

Instead of querying a secondary index by foreign key, Dynamoid caches the partition keys of associated models directly on the declaring item inside a DynamoDB Set attribute. Loading an association then uses fast direct point fetching or batch point fetching without scanning tables or querying secondary indexes.

This storage strategy involves two deliberate simplifications:

* *Sets for all associations* — to keep the implementation uniform across all macros, Dynamoid uses a `<association>_ids` set attribute even for `has_one` and `belongs_to` associations, where the set holds only a single partition key.
* *Simple primary keys only* — because DynamoDB sets can only store scalar values, cached IDs only store partition keys. Models with composite primary keys (partition key and sort key) cannot declare or participate in associations.

For `Author` (`has_many :books`) and `Book` (`belongs_to :author`), linking models stores the following attributes on their DynamoDB items:

```ruby
author = Author.create(name: 'Ursula K. Le Guin')
book = author.books.create(title: 'A Wizard of Earthsea')

# Stored on the Author item:
author.books_ids # => #<Set: {"b92d1e..."}>

# Stored on the Book item:
book.author_ids  # => #<Set: {"f41a8c..."}>
```

If `Book` specifies `belongs_to :author, foreign_key: :author_id`, the `Book` item stores the partition key as a scalar string under `author_id` instead:

```ruby
book.author_id # => "f41a8c..."
```

Storing the foreign key as a scalar attribute is necessary if you plan to index it with a Global Secondary Index, as DynamoDB does not allow indexing Set attributes.

Relying on cached IDs rather than secondary indexes creates two distinct trade-offs:

* *Item size growth* — every linked model adds an ID to the parent item's `<association>_ids` set. For high-cardinality relationships, this expands the item's payload, consumes more read and write capacity, and can eventually hit DynamoDB's hard 400 KB item size limit.
* *Outdated cached IDs* — because references are maintained entirely by Dynamoid in application code, deleting an item outside Dynamoid (or via class-level `Model.delete(id)`) leaves stale, orphaned IDs in the associated model's cached set.

{{#include ../_includes/feedback.md}}
