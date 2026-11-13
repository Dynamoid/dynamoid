# Callbacks

Callbacks are hooks into a model's lifecycle that let you run logic before, after, or around specific events—such as validating attributes, saving an item to DynamoDB, or loading a model into memory.

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

For short, inline logic that does not need a dedicated method, pass a block instead of a method name. The block executes in the context of the model instance:

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

  around_save :log_save

  private

  def log_save
    puts 'Saving user...'
    yield
    puts 'User saved'
  end
end
```

## Conditional Callbacks

To run a callback only when a specific condition is met, pass the `:if` or `:unless` option with a method name symbol:

```ruby
class User
  include Dynamoid::Document

  field :email

  before_validation :normalize_email, if: :email_present?

  private

  def email_present?
    email.present?
  end

  def normalize_email
    self.email = email.downcase
  end
end
```

For short inline conditions, pass a lambda to `:if` or `:unless`. The lambda executes in the context of the model instance:

```ruby
class User
  include Dynamoid::Document

  field :email

  before_validation :normalize_email, if: -> { email.present? }

  private

  def normalize_email
    self.email = email.downcase
  end
end
```

## Halting Execution

To cancel a persistence operation from inside a `before_*` callback, call `throw :abort`. Halting the callback chain stops any subsequent callbacks from executing and prevents the write to DynamoDB. Non-bang methods (`save`, `update_attributes`, `destroy`) return `false`, while bang methods (`save!`, `create!`, `update_attributes!`, `destroy!`) raise an exception:

```ruby
class User
  include Dynamoid::Document

  field :role

  before_destroy :prevent_admin_deletion

  private

  def prevent_admin_deletion
    throw(:abort) if role == 'admin'
  end
end

user = User.create(role: 'admin')
user.destroy  # => false
user.destroy! # Raises Dynamoid::Errors::RecordNotDestroyed
```

## Available Callbacks

### Validation

The `validation` callbacks (`before_validation` and `after_validation`) run whenever a model is validated via `valid?` or before saving (`save`, `create`, `update_attributes`, and `Model.update`):

```ruby
class User
  include Dynamoid::Document

  field :name

  before_validation :strip_whitespace
  after_validation :log_validation_errors
end
```

### Save

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

### Create

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

### Update

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

### Destroy

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

### Initialize and Find

The `initialize` and `find` callbacks (`after_initialize` and `after_find`) run when models are instantiated in memory: `after_initialize` runs whenever a model is instantiated (via `new` or when loaded from DynamoDB), and `after_find` runs when a model is loaded from DynamoDB:

```ruby
class User
  include Dynamoid::Document

  field :name

  after_initialize :setup_transient_state
  after_find :decrypt_attributes
end
```

### Touch

The `touch` callback (`after_touch`) runs after a model's timestamps are updated via `touch`:

```ruby
class User
  include Dynamoid::Document

  field :name

  after_touch :expire_fragment_cache
end
```

### Commit and Rollback

The `commit` and `rollback` callbacks (`after_commit` and `after_rollback`) run only when a model is mutated inside a [Write Transaction](transactions.md#writing-transactions)—`after_commit` runs after the transaction succeeds, and `after_rollback` runs if the transaction fails or is rolled back:

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

1. `before_validation`
2. `after_validation`
3. `before_save`
4. `around_save` (before `yield`)
5. `before_create`
6. `around_create` (before `yield`)
7. *Item is written to DynamoDB (`yield`)*
8. `around_create` (after `yield`)
9. `after_create`
10. `around_save` (after `yield`)
11. `after_save`

### Updating a Model

When updating an existing model (`save` on a persisted instance, `update_attributes`, or `Model.update`), Dynamoid runs the `validation`, `save`, and `update` callbacks in the following order:

1. `before_validation`
2. `after_validation`
3. `before_save`
4. `around_save` (before `yield`)
5. `before_update`
6. `around_update` (before `yield`)
7. *Item is updated in DynamoDB (`yield`)*
8. `around_update` (after `yield`)
9. `after_update`
10. `around_save` (after `yield`)
11. `after_save`

### Destroying a Model

When destroying a model (`destroy`), Dynamoid runs the `destroy` callbacks in the following order:

1. `before_destroy`
2. `around_destroy` (before `yield`)
3. *Item is deleted from DynamoDB (`yield`)*
4. `around_destroy` (after `yield`)
5. `after_destroy`

{{#include ../_includes/feedback.md}}
