## Rake Tasks

There are a few Rake tasks available out of the box:

* `rake dynamoid:create_tables`
* `rake dynamoid:ping`

In order to use them in non-Rails application they should be required
explicitly:

```ruby
# Rakefile

Rake::Task.define_task(:environment)
require 'dynamoid/tasks'
```

The Rake tasks depend on `:environment` task so it should be declared as
well.
