# Ruby & Library Code Documentation Standards

This guide establishes conventions for code snippets, examples, and technical contracts in Ruby library documentation.

## 1. Code Snippet Principles

### Realistic Domain Models & Natural Identity
Always model real-world domains (`User`, `Order`, `Product`, `LineItem`, `Account`) with semantic attributes (`email`, `status`, `total_cents`, `created_at`).

Preserve natural entity identity in examples:
* An entity's own primary identifier belongs in the partition key (e.g., `id` or `order_id` on `Order`).
* Sort keys should represent natural child attributes, timestamps (`placed_at`), or foreign keys (`customer_id`), not the entity's primary identity.

Ensure snippets are self-contained so developers understand the context without guessing.

### Feature Isolation in Examples
Keep code examples laser-focused on the specific method or option being introduced:
* Strip away unrelated configuration options. For example, when demonstrating `range` for sort keys, do not introduce custom partition key names, key types, or billing modes.
* Rely on framework conventions and defaults for everything outside the feature under discussion.

### Omit Redundant Default Arguments
When introducing a method whose arguments have sensible defaults, show the minimal call first:
* *Baseline:* `range :customer_id` (relies on the default `:string` type).
* *Customization:* `range :placed_at, :datetime` (introduces explicit non-default types).

Never pass the default argument explicitly in the introductory snippet if the accompanying text immediately explains that it defaults to that value anyway.

### Explicit Returns and Exceptions
Always show what the code returns or raises using inline comments:

```ruby
# Good: Shows explicit boolean return and object state
user = User.new(name: 'Alice')
user.save # => true
user.persisted? # => true

# Good: Shows explicit exception class
user = User.create!(name: '') # Raises Dynamoid::Errors::DocumentNotValid
```

### Modern, Idiomatic Ruby
Follow standard Ruby style conventions (2 spaces indentation, frozen string literal awareness, hash syntax with symbols `{ status: :active }`). Avoid deprecated gem APIs or old Ruby paradigms (e.g., avoid legacy dynamic finders `find_by_name`).

## 2. Progressive Disclosure in Code Examples

Structure code walkthroughs from the simple default to advanced customization:

1. **The Conventional Case (80%):**
   Show the simplest, idiomatic way to achieve the goal following convention over configuration:
   ```ruby
   class User
     include Dynamoid::Document

     field :email, :string
   end
   ```
2. **The Customized Case:**
   Introduce options only after the baseline is established:
   ```ruby
   class Order
     include Dynamoid::Document

     range :customer_id
     field :total, :number
   end
   ```
3. **Advanced / Edge Cases:**
   Show overrides, custom serialization, or complex queries in dedicated subsections with clear warnings or caveats.

## 3. Grounding Code in the Codebase

Documentation is a product contract. Before documenting any method, option, or error:

1. **Verify Method Names & Signatures:** Search the gem's source code (`lib/`) for the method definition and check its argument types and keyword options.
2. **Warning-Free Code Contracts (Accessor Collisions):** When the framework automatically generates default fields and accessor methods on include (`:id`, `:created_at`, `:updated_at`), never teach overriding their types by simply redeclaring `field :id, :integer`. That causes runtime logger warnings (`Method id generated for the field id overrides already existing method`). Always demonstrate the official suppression hook (`table skip_generating_fields: [:id]`).
3. **Check for Deprecations:** Verify whether an older method triggers a deprecation warning (`Dynamoid.deprecator.warn`). Never teach deprecated syntax in getting-started or user guides.
4. **Verify Raised Exceptions:** Confirm the exact exception class raised by inspecting `lib/dynamoid/errors.rb` or the method implementation (e.g., `Dynamoid::Errors::RecordNotFound` vs `RecordNotUnique`).
5. **Avoid Low-Level SDK Leaks:** When explaining high-level model operations, avoid exposing internal AWS SDK method names (e.g., say "efficient batch delete" rather than "issues a `BatchWriteItem` request") unless specifically discussing adapter internals or performance ceilings.
