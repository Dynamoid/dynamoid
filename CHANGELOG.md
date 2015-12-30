# 1.1.0

* Added support for optimistic locking on delete (PR #29, sumocoder)
* upgrade concurrent-ruby requirement to 1.0 (PR #31, keithmgould)

# 1.0.0

* Add support for AWS SDK v2.
* Add support for custom class type for fields.
* Remove partitioning support.
* Remove support for Dynamoid's (pseudo)indexes, now that DynamoDB offers
  local and global indexes.
* Rename :float field type to :number.
* Rename Chain#limit to Chain#eval_limit.

Housekeeping:

* Switch from `fake_dynamo` for unit tests to DynamoDBLocal. This is the new authoritative
  implementation of DynamoDB for testing, and it supports AWS SDK v2.
* Use Travis CI to auto-run unit tests on multiple Rubies.
* Randomize spec order.
