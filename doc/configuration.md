# Configuration

Listed below are all configuration options.

* `adapter` - useful only for the gem developers to switch to a new
  adapter. Default and the only available value is `aws_sdk_v3`
* `namespace` - prefix for table names, default is
  `dynamoid_#{application_name}_#{environment}` for Rails application
  and `dynamoid` otherwise
* `logger` - by default it's a `Rails.logger` in Rails application and
  `stdout` otherwise. You can disable logging by setting `nil` or
  `false` values. Set `true` value to use defaults
* `access_key` - DynamoDB custom access key for AWS credentials, override global
  AWS credentials if they're present
* `secret_key` - DynamoDB custom secret key for AWS credentials, override global
  AWS credentials if they're present
* `credentials` - DynamoDB custom pre-configured credentials, override global
  AWS credentials if they're present
* `region` - DynamoDB custom credentials for AWS, override global AWS
  credentials if they're present
* `batch_size` - when you try to load multiple items at once with
* `batch_get_item` call Dynamoid loads them not with one api call but
  in chunks. Default is 100 items
* `capacity_mode` - used at a table creation and means whether a table
  read/write capacity mode will be on-demand or provisioned. Allowed
  values are `:on_demand` and `:provisioned`. Default value is `nil` which
  means provisioned mode will be used.
* `read_capacity` - is used during table or index creation. Default is 100
  (units)
* `write_capacity` - is used during table or index creation. Default is 20
  (units)
* `warn_on_scan` - log warnings when scan table. Default is `true`
* `error_on_scan` - raises an error when scan table. Default is `false`
* `endpoint` - if provided, it communicates with the DynamoDB listening
  at the endpoint. This is useful for testing with
  [DynamoDB Local](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html)
* `identity_map` - ensures that each object gets loaded only once by
  keeping every loaded object in a map. Looks up objects using the map
  when referring to them. Isn't thread safe. Default is `false`.
  `Use Dynamoid::Middleware::IdentityMap` to clear identity map for each HTTP request
* `timestamps` - by default Dynamoid sets `created_at` and `updated_at`
  fields at model creation and updating. You can disable this
  behavior by setting `false` value
* `sync_retry_max_times` - when Dynamoid creates or deletes table
  synchronously it checks for completion specified times. Default is 60
  (times). It's a bit over 2 minutes by default
* `sync_retry_wait_seconds` - time to wait between retries. Default is 2
  (seconds)
* `convert_big_decimal` - if `true` then Dynamoid converts numbers
  stored in `Hash` in `raw` field to float. Default is `false`
* `store_attribute_with_nil_value` - if `true` Dynamoid keeps attribute
  with `nil` value in a document. Otherwise Dynamoid removes it while
  saving a document. Default is `nil` which equals behaviour with `false`
  value.
* `models_dir` - `dynamoid:create_tables` rake task loads DynamoDB
  models from this directory. Default is `./app/models`.
* `application_timezone` - Dynamoid converts all `datetime` fields to
  specified time zone when loads data from the storage.
  Acceptable values - `:utc`, `:local` (to use system time zone) and
  time zone name e.g. `Eastern Time (US & Canada)`. Default is `utc`
* `dynamodb_timezone` - When a datetime field is stored in string format
  Dynamoid converts it to specified time zone when saves a value to the
  storage. Acceptable values - `:utc`, `:local` (to use system time
  zone) and time zone name e.g. `Eastern Time (US & Canada)`. Default is
  `utc`
* `store_datetime_as_string` - if `true` then Dynamoid stores :datetime
  fields in ISO 8601 string format. Default is `false`
* `store_date_as_string` - if `true` then Dynamoid stores :date fields
  in ISO 8601 string format. Default is `false`
* `store_empty_string_as_nil` - store attribute's empty String value as NULL. Default is `true`
* `store_boolean_as_native` - if `true` Dynamoid stores boolean fields
  as native DynamoDB boolean values. Otherwise boolean fields are stored
  as string values `'t'` and `'f'`. Default is `true`
* `store_binary_as_native` - if `true` Dynamoid stores binary fields
  as native DynamoDB binary values. Otherwise binary fields are stored
  as Base64 encoded string values. Default is `false`
* `backoff` - is a hash: key is a backoff strategy (symbol), value is
  parameters for the strategy. Is used in batch operations. Default id
  `nil`
* `backoff_strategies`: is a hash and contains all available strategies.
  Default is `{ constant: ..., exponential: ...}`
* `log_formatter`: overrides default AWS SDK formatter. There are
  several canned formatters: `Aws::Log::Formatter.default`,
  `Aws::Log::Formatter.colored` and `Aws::Log::Formatter.short`. Please
  look into `Aws::Log::Formatter` AWS SDK documentation in order to
  provide own formatter.
* `http_continue_timeout`: The number of seconds to wait for a
  100-continue HTTP response before sending the request body. Default
  option value is `nil`. If not specified effected value is `1`
* `http_idle_timeout`: The number of seconds an HTTP connection is
  allowed to sit idle before it is considered stale. Default option
  value is `nil`. If not specified effected value is `5`
* `http_open_timeout`: The number of seconds to wait when opening a HTTP
  session. Default option value is `nil`. If not specified effected
  value is `15`
* `http_read_timeout`:The number of seconds to wait for HTTP response
  data. Default option value is `nil`. If not specified effected value
  is `60`
* `create_table_on_save`: if `true` then Dynamoid creates a
  corresponding table in DynamoDB at model persisting if the table
  doesn't exist yet. Default is `true`
