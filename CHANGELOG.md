# HEAD

## Breaking

* N/A

## Improvements

* N/A

## Fixes

* Bug: [#255](https://github.com/Dynamoid/Dynamoid/pull/255) Fix Vagrant RVM configuration and upgrade to Ruby 2.4.1 (@richardhsu)

# 2.1.0

## Breaking

* N/A

## Improvements

* Feature: [#221](https://github.com/Dynamoid/Dynamoid/pull/221) Add field declaration option `of` to specify the type of `set` elements (@pratik60)
* Feature: [#223](https://github.com/Dynamoid/Dynamoid/pull/223) Add field declaration option `store_as_string` to store `datetime` as ISO-8601 formatted strings (@william101)
* Feature: [#228](https://github.com/Dynamoid/Dynamoid/pull/228) Add field declaration option `store_as_string` to store `date` as ISO-8601 formatted strings (@andrykonchin)
* Feature: [#229](https://github.com/Dynamoid/Dynamoid/pull/229) Support hash argument for `start` chain method (@mnussbaumer)
* Feature: [#236](https://github.com/Dynamoid/Dynamoid/pull/236) Change log level from `info` to `debug` for benchmark logging (@kicktheken)
* Feature: [#239](https://github.com/Dynamoid/Dynamoid/pull/239) Add methods for low-level updating: `.update`, `.update_fields` and `.upsert` (@andrykonchin)
* Feature: [#243](https://github.com/Dynamoid/Dynamoid/pull/243) Support `ne` condition operator (@andrykonchin)
* Feature: [#246](https://github.com/Dynamoid/Dynamoid/pull/246) Added support of backoff in batch operations (@andrykonchin)
    * added global config options `backoff` and `backoff_strategies` to configure backoff
    * added `constant` and `exponential` built-in backoff strategies
    * `.find_all` and `.import` support new backoff options

## Fixes

* Bug: [#216](https://github.com/Dynamoid/Dynamoid/pull/216) Fix global index detection in queries with conditions other than equal (@andrykonchin)
* Bug: [#224](https://github.com/Dynamoid/Dynamoid/pull/224) Fix how `contains` operator works with `set` and `array` field types (@andrykonchin)
* Bug: [#225](https://github.com/Dynamoid/Dynamoid/pull/225) Fix equal conditions for `array` fields (@andrykonchin)
* Bug: [#229](https://github.com/Dynamoid/Dynamoid/pull/229) Repair support `start` chain method on Scan operation (@mnussbaumer)
* Bug: [#238](https://github.com/Dynamoid/Dynamoid/pull/238) Fix default value of `models_dir` config option (@baloran)
* Bug: [#244](https://github.com/Dynamoid/Dynamoid/pull/244) Allow to pass empty strings and sets to `.import` (@andrykonchin)
* Bug: [#246](https://github.com/Dynamoid/Dynamoid/pull/246) Batch operations (`batch_write_item` and `batch_read_item`) handle unprocessed items themselves (@andrykonchin)
* Bug: [#250](https://github.com/Dynamoid/Dynamoid/pull/250) Update outdated warning message about inefficient query and missing indices (@andrykonchin)
* Bug: [252](https://github.com/Dynamoid/Dynamoid/pull/252) Don't loose nanoseconds when store DateTime as float number

# 2.0.0

## Breaking

Breaking changes in this release generally bring Dynamoid behavior closer to the Rails-way.

* Change: [#186](https://github.com/Dynamoid/Dynamoid/pull/186) Consistent behavior for `Model.where({}).all` (@andrykonchin)
    * <= 1.3.x behaviour -
        * load lazily if user specified batch size
        * load all collection into memory otherwise
    * New behaviour -
        * always return lazy evaluated collection
        * It means Model.where({}).all returns Enumerator instead of Array.
        * If you need Array interface you have to convert collection to Array manually with to_a method call
* Change: [#195](https://github.com/Dynamoid/Dynamoid/pull/195) Failed `#find` returns error (@andrykonchin)
    * <= 1.3.x behaviour - find returns nil or smaller array.
    * New behaviour - it raises RecordNotFound if one or more records can not be found for the requested ids
* Change: [#196](https://github.com/Dynamoid/Dynamoid/pull/196) Return value of `#save` (@andrykonchin)
    * <= 1.3.x behaviour - save returns self if model is saved successfully
    * New behaviour - it returns true

## Improvements

* Feature: [#185](https://github.com/Dynamoid/Dynamoid/pull/185) `where`, finders and friends take into account STI (single table inheritance) now (@andrykonchin)
    * query will return items of the model class and all subclasses
* Feature: [#190](https://github.com/Dynamoid/Dynamoid/pull/190) Allow passing options to range when defining attributes of the document (@richardhsu)
    * Allows for serialized fields and passing the serializer option.
* Feature: [#198](https://github.com/Dynamoid/Dynamoid/pull/198) Enhanced `#create` and `#create!` to allow multiple document creation like `#import` (@andrykonchin)
    * `User.create([{name: 'Josh'}, {name: 'Nick'}])`
* Feature: [#199](https://github.com/Dynamoid/Dynamoid/pull/199) Added `Document.import` method (@andrykonchin)
* Feature: [#205](https://github.com/Dynamoid/Dynamoid/pull/205) Use batch deletion via `batch_write_item` for `delete_all` (@andrykonchin)
* Rename: [#205](https://github.com/Dynamoid/Dynamoid/pull/205) `Chain#destroy_all` as `Chain#delete_all`, to better match Rails conventions when no callbacks are run (@andrykonchin)
    * kept the old name as an alias, for backwards compatibility
* Feature: [#207](https://github.com/Dynamoid/Dynamoid/pull/207) Added slicing by 25 requests in #batch_write_item (@andrykonchin)
* Feature: [#211](https://github.com/Dynamoid/Dynamoid/pull/211) Improved Vagrant setup for testing (@richardhsu)
* Feature: [#212](https://github.com/Dynamoid/Dynamoid/pull/212) Add foreign_key option (@andrykonchin)
* Feature: [#213](https://github.com/Dynamoid/Dynamoid/pull/213) Support Boolean raw type (@andrykonchin)
* Improved Documentation (@pboling, @andrykonchin)

## Fixes

* Bug: [#191](https://github.com/Dynamoid/Dynamoid/pull/191), [#192](https://github.com/Dynamoid/Dynamoid/pull/192) Support lambdas as fix for value types were not able to be used as default values (@andrykonchin)(@richardhsu)
* Bug: [#202](https://github.com/Dynamoid/Dynamoid/pull/202) Fix several issues with associations (@andrykonchin)
    * setting `nil` value raises an exception
    * document doesn't keep assigned model and loads it from the storage
    * delete call doesn't update cached ids of associated models
    * fix clearing old `has_many` association while add model to new `has_many` association
* Bug: [#204](https://github.com/Dynamoid/Dynamoid/pull/204) Fixed issue where `Document.where(:"id.in" => [])` would do `Query` operation instead of `Scan` (@andrykonchin)
    * Fixed `Chain#key_present?`
* Bug: [#205](https://github.com/Dynamoid/Dynamoid/pull/205) Fixed `delete_all` (@andrykonchin)
    * Fixed exception when makes scan and sort key is declared in model
    * Fixed exception when makes scan and any condition is specified in where clause (like Document.where().delete_all)
    * Fixed exception when makes query and sort key isn't declared in model
* Bug: [#207](https://github.com/Dynamoid/Dynamoid/pull/207) Fixed `#delete` method for case `adapter.delete(table_name, [1, 2, 3], range_key: 1)` (@andrykonchin)

# 1.3.4

## Improvements

* Added `Chain#last` method (@andrykonchin)
* Added `date` field type (@andrykonchin)
* Added `application_timezone` config option (@andrykonchin)
* Allow consistent reading for Scan request (@andrykonchin)
* Use Query instead of Scan if there are no conditions for sort (range) key in where clause (@andrykonchin)
* Support condition operators for non-key fields for Query request (@andrykonchin)
* Support condition operators for Scan request (@andrykonchin)
* Support additional operators `in`, `contains`, `not_contains` (@andrykonchin)
* Support type casting in `where` clause (@andrykonchin)
* Rename `Chain#eval_limit` to `#record_limit` (@richardhsu)
* Add `Chain#scan_limit` (@richardhsu)
* Support batch loading for Query requests (@richardhsu)
* Support querying Global/Local Secondary Indices in `where` clause (@richardhsu)
* Only query on GSI if projects all attributes in `where` clause (@richardhsu)

## Fixes

* Fix incorrect applying of default field value (#36 and #117, @andrykonchin)
* Fix sync table creation/deletion (#160, @mirokuxy)
* Allow to override document timestamps (@andrykonchin)
* Fix storing empty array as nil (#8, @andrykonchin)
* Fix `limit` handling for Query requests (#85, @richardhsu)
* Fix `limit` handling for Scan requests (#85, @richardhsu)
* Fix paginating for Query requests (@richardhsu)
* Fix paginating for Scan requests (@richardhsu)
* Fix `batch_get_item` method call for integer partition key (@mudasirraza)

# 1.3.3

* Allow configuration of the Dynamoid models directory, as not everyone keeps non AR models in app/models
  - Dynamoid::Config.models_dir = "app/whatever"

# 1.3.2

* Fix migrations by stopping the loading of all rails models outside the rails env.

# 1.3.1

* Implements #135
  * dump values for :integer, :string, :boolean fields passed to where query
    * e.g. You can search for booleans with any of: `[true, false, "t", "f", "true", "false"]`
* Adds support for Rails 5 without warnings.
* Adds rake tasks for working with a DynamoDB database:
  * rake dynamoid:create_tables
  * rake dynamoid:ping
* Automatically requires the Railtie when in Rails (which loads the rake tasks)
* Prevent duplicate entries in Dynamoid.included_models
* Added wwtd and appraisal to spec suite for easier verification of the compatibility matrix
* Support is now officially Ruby 2.0+, (including JRuby 9000) and Rails 4.0+

# 1.3.0

* Fixed specs (@AlexNisnevich & @pboling)
* Fix `blank?` and `present?` behavior for single associations (#110, @AlexNisnevich & @bayesimpact)
* Support BatchGet for more than 100 items (#80, @getninjas)
* Add ability to specify connection settings specific to Dynamoid (#116, @NielsKSchjoedt)
* Adds Support for Rails 5! (#109, @gastzars)
* Table Namespace Fix (#79, @alexperto)
* Improve Testing Docs (#103, @tadast)
* Query All Items by Looping (#102, @richardhsu)
* Store document in DocumentNotValid error for easier debugging (#98, holyketzer)
* Better support for raw datatype (#104, @OpenGov)
* Fix associative tables with non-id primary keys (#86, @everett-wetchler)

# 1.2.1

* Remove accidental Gemfile.lock; fix .gitignore (#95, @pboling)
* Allow options to put_items (#95, @alexperto)
* Support range key in secondary index queries (#95, @pboling)
* Better handling of options generally (#95, @pboling)
* Support for batch_delete_item API (#95, @pboling)
* Support for batch_write_item API (#95, @alexperto)

# 1.2.0

* Add create_table_syncronously, and sync: option to regular create_table (@pboling)
  * make required for tables created with secondary indexes
* Expose and fix truncate method on adapter (#52, @pcorpet)
* Enable saving without updating timestamps (#58, @cignoir)
* Fix projected attributes by checking for :include (#56, @yoshida_tetsuhiro)
* Make behavior of association where method closer to AR by cloning instead of modifying (#51, @pcorpet)
* Add boolean field presence validator (#50, @pcorpet)
* Add association build method (#49, @pcorpet)
* Fix association create method (#47, #48, @pcorpet)
* Support range_between (#42, @ayemos)
* Fix problems with range query (#42, @ayemos)
* Don't prefix table names when namespace is nil (#40, @brenden)
* Added basic secondary index support (#34, @sumocoder)
* Fix query attribute behavior for booleans (#35, @amirmanji)
* Ignore unknown fields on model initialize (PR #33, @sumocoder)

# 1.1.0

* Added support for optimistic locking on delete (PR #29, @sumocoder)
* upgrade concurrent-ruby requirement to 1.0 (PR #31, @keithmgould)

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
