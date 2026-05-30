### Updating

In order to update document you can use high level methods
`#update_attributes`, `#update_attribute` and `.update`. They run
validation and callbacks.

```ruby
Address.find(id).update_attributes(city: 'Chicago')
Address.find(id).update_attribute(:city, 'Chicago')
Address.update(id, city: 'Chicago')
```

There are also some low level methods `#update`, `.update_fields` and
`.upsert`. They don't run validation and callbacks (except `#update` -
it runs `update` callbacks). All of them support conditional updates.
`#upsert` will create new document if document with specified `id`
doesn't exist.

```ruby
Address.find(id).update do |i|
  i.set city: 'Chicago'
  i.add latitude: 100
  i.delete set_of_numbers: 10
end
Address.find(id).update(if: { deliverable: true }) do |i|
  i.set city: 'Chicago'
end
Address.update_fields(id, city: 'Chicago')
Address.update_fields(id, { city: 'Chicago' }, if: { deliverable: true })
Address.upsert(id, city: 'Chicago')
Address.upsert(id, { city: 'Chicago' }, if: { deliverable: true })
```

By default, `#upsert` will update all attributes of the document if it already exists.
To idempotently create-but-not-update a record, apply the `unless_exists` condition
to its keys when you upsert.

```ruby
Address.upsert(id, { city: 'Chicago' }, { unless_exists: [:id] })
```

