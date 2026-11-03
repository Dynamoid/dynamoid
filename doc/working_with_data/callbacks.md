# Callbacks

Callbacks are hooks into a model's lifecycle that let you run logic before, after, or around specific events—such as validating attributes, saving an item to DynamoDB, or loading a model into memory.

## Lifecycle Events

Dynamoid provides callbacks for the core persistence lifecycle events:

* `validation`
* `save`
* `create`
* `update`
* `destroy`

It also provides callbacks for model instantiation, timestamp updates, and transactions:

* `initialize`
* `find`
* `touch`
* `commit`
* `rollback`

## Defining Callbacks

To register a callback, pass a method name as a symbol:

```ruby
class User
  include Dynamoid::Document

  field :email

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.downcase if email.present?
  end
end
```

You can also register a callback by passing a block instead of a method name. The block executes in the context of the model instance:

```ruby
class User
  include Dynamoid::Document

  field :email

  before_validation do
    self.email = email.downcase if email.present?
  end
end
```

Unlike `before_*` and `after_*` callbacks, an `around_*` callback wraps the underlying event and must `yield` for the operation to proceed:

```ruby
class User
  include Dynamoid::Document

  field :name

  around_save :wrap_save

  private

  def wrap_save
    # before save
    yield
    # after save
  end
end
```

You can control whether a callback runs by passing `:if` or `:unless` options with a method name symbol or a lambda:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :role

  before_save :normalize_name, if: :name_present?
  after_create :notify_admin, unless: -> { role == 'guest' }

  private

  def name_present?
    name.present?
  end

  def normalize_name
    # ...
  end

  def notify_admin
    # ...
  end
end
```

## Available Callbacks

### Validation Callbacks

The `validation` callbacks (`before_validation` and `after_validation`) run whenever a model is validated via `valid?` or before saving (`save`, `create`, `update_attributes`, and `Model.update`):

```ruby
class User
  include Dynamoid::Document

  field :name

  before_validation :strip_whitespace
  after_validation :log_validation_errors
end
```

### Save Callbacks

The `save` callbacks (`before_save`, `around_save`, and `after_save`) run whenever a model is saved (`save`, `create`, `update_attributes`, and `Model.update`), regardless of whether it is a new model or an already-persisted one:

```ruby
class User
  include Dynamoid::Document

  field :name

  before_save :prepare_attributes
  around_save :wrap_save
  after_save :clear_cached_profile
end
```

### Create Callbacks

The `create` callbacks (`before_create`, `around_create`, and `after_create`) run only when a new model is persisted to DynamoDB for the first time (`save` on a new instance, or `create`):

```ruby
class User
  include Dynamoid::Document

  field :name

  before_create :assign_defaults
  around_create :wrap_create
  after_create :send_welcome_email
end
```

### Update Callbacks

The `update` callbacks (`before_update`, `around_update`, and `after_update`) run when an existing model is updated (`save` on a persisted instance, `update_attributes`, `Model.update`, or an atomic `#update` block):

```ruby
class User
  include Dynamoid::Document

  field :name

  before_update :audit_changes
  around_update :wrap_update
  after_update :sync_search_index
end
```

### Destroy Callbacks

The `destroy` callbacks (`before_destroy`, `around_destroy`, and `after_destroy`) run when a model is destroyed via `destroy`:

```ruby
class User
  include Dynamoid::Document

  field :name

  before_destroy :check_dependencies
  around_destroy :wrap_destroy
  after_destroy :cleanup_storage
end
```

### Initialize and Find Callbacks

The `initialize` and `find` callbacks (`after_initialize` and `after_find`) run when models are instantiated in memory: `after_initialize` runs whenever a model is instantiated (via `new` or when loaded from DynamoDB), and `after_find` runs when a model is loaded from DynamoDB:

```ruby
class User
  include Dynamoid::Document

  field :name

  after_initialize :setup_transient_state
  after_find :decrypt_attributes
end
```

### Touch Callbacks

The `touch` callback (`after_touch`) runs after a model's timestamps are updated via `touch`:

```ruby
class User
  include Dynamoid::Document

  field :name

  after_touch :expire_fragment_cache
end
```

### Commit and Rollback Callbacks

The `commit` and `rollback` callbacks (`after_commit` and `after_rollback`) run only when a model is mutated inside a [Write Transaction](transactions.md)—`after_commit` runs after the transaction succeeds, and `after_rollback` runs if the transaction fails or is rolled back:

```ruby
class User
  include Dynamoid::Document

  field :name

  after_commit :publish_event
  after_rollback :reset_local_state
end
```

## Callback Order

Because a single persistence operation can trigger multiple lifecycle events, Dynamoid runs their callbacks in a nested sequence.

### Creating a Model

When creating a new model (`save` on a new instance, or `create`), Dynamoid runs the `validation`, `save`, and `create` callbacks in the following order:

* `before_validation`
* `after_validation`
* `before_save`
* `around_save` (before `yield`)
* `before_create`
* `around_create` (before `yield`)
* `around_create` (after `yield`)
* `after_create`
* `around_save` (after `yield`)
* `after_save`

### Updating a Model

When updating an existing model (`save` on a persisted instance, `update_attributes`, or `Model.update`), Dynamoid runs the `validation`, `save`, and `update` callbacks in the following order:

* `before_validation`
* `after_validation`
* `before_save`
* `around_save` (before `yield`)
* `before_update`
* `around_update` (before `yield`)
* `around_update` (after `yield`)
* `after_update`
* `around_save` (after `yield`)
* `after_save`

### Destroying a Model

When destroying a model (`destroy`), Dynamoid runs the `destroy` callbacks in the following order:

* `before_destroy`
* `around_destroy` (before `yield`)
* `around_destroy` (after `yield`)
* `after_destroy`

## Halting Execution

To cancel a persistence operation from inside any `before_*` callback, call `throw :abort`. Halting the callback chain stops any subsequent callbacks and prevents the write to DynamoDB. Non-bang methods (`save`, `create`, `update_attributes`, `Model.update`, `destroy`) return `false`, whereas bang methods (`save!`, `create!`, `update_attributes!`, `Model.update!`, `destroy!`) raise an exception:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :role

  before_destroy :prevent_admin_deletion

  private

  def prevent_admin_deletion
    throw(:abort) if role == 'admin'
  end
end

admin.destroy  # => false
admin.destroy! # Raises Dynamoid::Errors::RecordNotDestroyed
```

{{#include ../_includes/feedback.md}}
