### Global Secondary Indexes

You can define an index with `global_secondary_index`:

```ruby
class User
  include Dynamoid::Document

  field :name
  field :age, :number

  global_secondary_index hash_key: :age # Must come after field definitions.
end
```

The following options are available:
* `hash_key` - is used as the hash key of an index,
* `range_key` - is used as the range key of an index,
* `projected_attributes` - list of fields to store in an index or has a
  predefined value `:keys_only`, `:all`; `:keys_only` is the default,
* `name` - an index will be created with this name when a table is
  created; by default, the name is generated and contains the table name and keys
  names,
* `read_capacity` - is used when the table is created and used as an index
  capacity; by default, it equals `Dynamoid::Config.read_capacity`,
* `write_capacity` - is used when the table is created and used as an index
  capacity; by default, it equals `Dynamoid::Config.write_capacity`

The only mandatory option is `name`.

**WARNING:** In order to use global secondary index in `Document.where`
implicitly you need to have all the attributes of the original table in
the index and declare it with option `projected_attributes: :all`:

```ruby
class User
  # ...

  global_secondary_index hash_key: :age, projected_attributes: :all
end
```

There is only one implicit way to query Global and Local Secondary
Indexes (GSI/LSI).

#### Implicit

The second way implicitly uses your GSI through the `where` clauses and
deduces the index based on the query fields provided. Another added
benefit is that it is built into query chaining so you can use all the
methods used in normal querying. The explicit way from above would be
rewritten as follows:

```ruby
where(dynamo_primary_key_column_name => dynamo_primary_key_value,
      "#{range_column}.#{range_modifier}" => range_value)
  .scan_index_forward(false)
```

The only caveat with this method is that because it is also used for
general querying, it WILL NOT use a GSI unless it explicitly has defined
`projected_attributes: :all` on the GSI in your model. This is because
GSIs that do not have all attributes projected will only contain the
index keys and therefore will not return objects with fully resolved
field values. It currently opts to provide the complete results rather
than partial results unless you've explicitly looked up the data.

*Future TODO could involve implementing `select` in chaining as well as
resolving the fields with a second query against the table since a query
against GSI then a query on base table is still likely faster than scan
on the base table*
