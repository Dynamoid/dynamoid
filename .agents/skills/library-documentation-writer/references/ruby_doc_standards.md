# Ruby & Library Code Documentation Standards

This guide establishes conventions for code snippets, examples, and technical contracts in Ruby library documentation.

---

## 1. Code Snippet Principles

### Realistic Domain Models
* **Avoid `Foo`, `Bar`, and `Baz`:** Always use real-world domain models (`User`, `Order`, `Product`, `LineItem`, `Account`).
* **Semantic Attributes:** Attribute names should reflect realistic application data (`email`, `status`, `total_cents`, `created_at`).
* **Self-Contained Snippets:** Code samples should include the required class declaration or context so a developer can understand how the code fits together without guessing.

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
* Follow standard Ruby style conventions (2 spaces indentation, frozen string literal awareness, hash syntax with symbols `{ status: :active }`).
* Avoid deprecated gem APIs or old Ruby paradigms (e.g., avoid legacy dynamic finders `find_by_name`).

---

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

     table name: :custom_orders, key: :order_id
     range :sequence_number, :integer
     field :total, :number
   end
   ```
3. **Advanced / Edge Cases:**
   Show overrides, custom serialization, or complex queries in dedicated subsections with clear warnings or caveats.

---

## 3. Grounding Code in the Codebase

Documentation is a product contract. Before documenting any method, option, or error:

1. **Verify Method Names & Signatures:** Search the gem's source code (`lib/`) for the method definition and check its argument types and keyword options.
2. **Check for Deprecations:** Verify whether an older method triggers a deprecation warning (`Dynamoid.deprecator.warn`). Never teach deprecated syntax in getting-started or user guides.
3. **Verify Raised Exceptions:** Confirm the exact exception class raised by inspecting `lib/dynamoid/errors.rb` or the method implementation (e.g., `Dynamoid::Errors::RecordNotFound` vs `RecordNotUnique`).
4. **Avoid Low-Level SDK Leaks:** When explaining high-level model operations, avoid exposing internal AWS SDK method names (e.g., say "efficient batch delete" rather than "issues a `BatchWriteItem` request") unless specifically discussing adapter internals or performance ceilings.
