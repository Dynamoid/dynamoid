# Type casting

Dynamoid supports type casting and tries to do it in the most convenient
way. Values for all fields (except custom type) are coerced to declared
field types.

Some obvious rules are used, e.g.:

for boolean field:
```ruby
document.boolean_field = 'off'
# => false
document.boolean_field = 'false'
# => false
document.boolean_field = 'some string'
# => true
```

or for integer field:
```ruby
document.integer_field = 42.3
# => 42
document.integer_field = '42.3'
# => 42
document.integer_field = true
# => 1
```

If time zone isn't specified for `datetime` value - application time
zone is used.

To access field value before type casting following method could be
used: `attributes_before_type_cast` and
`read_attribute_before_type_cast`.

There is `<name>_before_type_cast` method for every field in a model as
well.
