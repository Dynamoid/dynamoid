# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
### Added
### Changed
### Removed

## 3.10.0
### Fixed
* [#681](https://github.com/Dynamoid/dynamoid/pull/681) Fixed saving persisted model and deleting attributes with `nil` value if `config.store_attribute_with_nil_value` is `false`
* [#716](https://github.com/Dynamoid/dynamoid/pull/716), [#691](https://github.com/Dynamoid/dynamoid/pull/691), [#687](https://github.com/Dynamoid/dynamoid/pull/687), [#660](https://github.com/Dynamoid/dynamoid/pull/660) Numerous fixes in README.md and RDoc documentation (@ndjndj, @kiharito, @dunkOnIT)
### Added
* [#656](https://github.com/Dynamoid/dynamoid/pull/656) Added a `create_table_on_save` configuration flag to create table on save (@imaximix)
* [#697](https://github.com/Dynamoid/dynamoid/pull/697) Ensure Ruby 3.3 and Rails 7.1 versions are supported and added them on CI
### Changed
* [#655](https://github.com/Dynamoid/dynamoid/pull/655) Support multiple `where` in the same chain with multiple conditions for the same field

## 3.9.0 / 2023-04-13
### Fixed
* [#610](https://github.com/Dynamoid/dynamoid/pull/610) Specs in JRuby; Support for JRuby 9.4.0.0 (@pboling)
* [#624](https://github.com/Dynamoid/dynamoid/pull/624) Fixed `#increment!`/`#decrement!` methods and made them compatible with Rails counterparts
* [#626](https://github.com/Dynamoid/dynamoid/pull/626) Fixed saving empty Set and String and replacing with `nil` in `#update`, `#update!`, `.update_fields`, and `.upsert` methods
* [#628](https://github.com/Dynamoid/dynamoid/pull/628) Fixed `.import` method to mark persisted model attributes as not changed/not dirty
* [#632](https://github.com/Dynamoid/dynamoid/pull/632) Fixed `#save` called with `touch: false` option to set `updated_at` attribute even for a new record (to comply with Rails)
* [#634](https://github.com/Dynamoid/dynamoid/pull/634) Fixed model callbacks:
  * changed order of `save` and `create`/`update` callbacks - `save` callbacks are outer for the `create`/`update` ones
  * removed `before_initialize` and `around_initialize` callbacks - there should be only `after_initialize` one
* [#634](https://github.com/Dynamoid/dynamoid/pull/634) Fixed `#touch` method compatibility with a Rails counterpart:
  * don't save other modified attributes - only timestamps
  * don't perform validation and don't call `save`/`create`/`update` callbacks
  * accept a list of attribute names, but not one name
  * accept a `:time` option
### Added
* [#611](https://github.com/Dynamoid/dynamoid/pull/611) Add `rubocop-md` (@pboling)
* [#612](https://github.com/Dynamoid/dynamoid/pull/612) Add `rubocop-rspec` (@pboling)
* [#613](https://github.com/Dynamoid/dynamoid/pull/613) Add `rubocop-performance` and `rubocop-rake` (@pboling)
  * Added `funding_uri` set to open collective: https://opencollective.com/dynamoid
  * Added `required_ruby_version` as `>= 2.3.0` (which was already the minimum supported version of Ruby)
* [#616](https://github.com/Dynamoid/dynamoid/pull/616) Upgrade `simplecov` (& remove `coveralls`) (@pboling)
  * Setup GitHub actions for Code Coverage
  * Setup GitHub actions for RuboCop linting
  * Automate coverage feedback on Pull Requests via GitHub Actions and CodeCov
* [#618](https://github.com/Dynamoid/dynamoid/pull/618) Upgrade README Badges (@pboling)
* [#624](https://github.com/Dynamoid/dynamoid/pull/624) Added `:touch` option for `.inc` method to be more compatible with the Rails counterpart method `.update_counters`
* [#627](https://github.com/Dynamoid/dynamoid/pull/627) Made the following methods in the Dirty API public (to comply with Rails):
  * `clear_changes_information`
  * `changes_applied`
  * `clear_attribute_changes`
* [#630](https://github.com/Dynamoid/dynamoid/pull/630) Added `Dynamoid::Adapter#execute` method to run PartiQL queries
* [#634](https://github.com/Dynamoid/dynamoid/pull/634) Added `after_touch` callback and run it in the following methods:
  * `#touch`
  * `#increment!`
  * `#decrement!`
* [#642](https://github.com/Dynamoid/dynamoid/pull/642) Run specs on CI against Ruby 3.2
* [#645](https://github.com/Dynamoid/dynamoid/pull/645) Added `after_find` callback
### Changed
* [#610](https://github.com/Dynamoid/dynamoid/pull/610) Switch to [`rubocop-lts`](https://rubocop-lts.gitlab.io/) (@pboling)
* [#633](https://github.com/Dynamoid/dynamoid/pull/633) Change `#inspect` method to return only attributes
* [#623](https://github.com/Dynamoid/dynamoid/pull/623) Optimized performance of persisting to send only changed attributes in a request to DynamoDB

## 3.8.0 / 2022-11-09
### Fixed
* [#525](https://github.com/Dynamoid/dynamoid/pull/525) Don't mark an attribute as changed if new assigned value equals the old one (@a5-stable)
* Minor changes in the documentation:
  * [#526](https://github.com/Dynamoid/dynamoid/pull/526) (@a5-stable)
  * [#528](https://github.com/Dynamoid/dynamoid/pull/528) (@a5-stable)
  * [#589](https://github.com/Dynamoid/dynamoid/pull/589) (@jrhoads)
* [#527](https://github.com/Dynamoid/dynamoid/pull/527) Fix `update_fields` and `upsert` methods - take into account the table-specific `timestamps` option for setting the `updated_at` attribute
(@oieioi)
* [#533](https://github.com/Dynamoid/dynamoid/pull/533) Allow attribute with custom type to be used as a partition or sort key of DynamoDB index (@rahul342)
* [#558](https://github.com/Dynamoid/dynamoid/pull/558) Change the way how a filename is derived from a model class name in a warning about using the Scan operation (@a5-stable)
* [#567](https://github.com/Dynamoid/dynamoid/pull/567) Fix `#reload` and mark a reloaded model as persisted
* [#573](https://github.com/Dynamoid/dynamoid/pull/573) Fix proxying of method calls with keyword arguments called on an association for Ruby 2.7 and above (@xeger)
* [#579](https://github.com/Dynamoid/dynamoid/pull/579) Fix `create_table` method when a `table_name` option passed in case a model has TTL setting enabled (@ta1kt0me)
* [#591](https://github.com/Dynamoid/dynamoid/pull/591) Multiple fixes:
  * Fix `#update` and `#update!` - take into account the table-specific `timestamps` option for setting the `updated_at` attribute
  * Fix `#update_attribute` - skip validation
  * Return `self` in some public methods to enable methods chaining
* [#601](https://github.com/Dynamoid/dynamoid/pull/601) Fix `#first` and `#pluck` methods: do not mutate query parameters and affect other query methods.

### Added
* [#531](https://github.com/Dynamoid/dynamoid/pull/531) Run `before_update` and `after_update` callbacks at saving a model (@a5-stable)
* [#536](https://github.com/Dynamoid/dynamoid/pull/536) Modernization
  * Support for Ruby 3.1
  * Support for Rails 7.0
  * Keep a Changelog Format

## 3.7.1 / 2021-06-30
### Fixed
* [#484](https://github.com/Dynamoid/dynamoid/pull/484) Fix model deletion - update cached foreign keys in associated models when delete a model
* [#492](https://github.com/Dynamoid/dynamoid/pull/492) Fix using `:date` field as an index hash/range key (@yoshida-eth0)
* [#503](https://github.com/Dynamoid/dynamoid/pull/503) Fix explicit forcing index with `#with_index` method when perform Scan operation (@bmalinconico)
* [#511](https://github.com/Dynamoid/dynamoid/pull/511) Fix `BatchGetItem` operation when partial result returned (so there are unprocessed keys) and table has a range key. The fix affects `.find_all` method only (@Bajena)

## 3.7.0 / 2021-02-02
### Added
* [#476](https://github.com/Dynamoid/dynamoid/pull/476) Added `#with_index` method to force an index in query (@bmalinconico)
* [#481](https://github.com/Dynamoid/dynamoid/pull/481) Added `alias` option to the `field` method to declare a field alias and use more conventional name to set and get value

### Changed
* [#482](https://github.com/Dynamoid/dynamoid/pull/482) Support Ruby 3.0 and Rails 6.1
* [#461](https://github.com/Dynamoid/dynamoid/pull/461) Allow to delete item attribute with `#update` method (@jkirsteins)
* [#463](https://github.com/Dynamoid/dynamoid/pull/463) Raise `UnknownAttribute` exception when specified not declared attribute name (@AlexGascon)

### Fixed
* [#480](https://github.com/Dynamoid/dynamoid/pull/480) Repair `.consistent`/`.delete_all`/`.destroy_all` calls directly on a model class
* [#484](https://github.com/Dynamoid/dynamoid/pull/484) Fix broken foreign keys after model deleting (@kkan)
* Fixed in Readme.md: [#470](https://github.com/Dynamoid/dynamoid/pull/470) (@rromanchuk), [#473](https://github.com/Dynamoid/dynamoid/pull/473) (@Rulikkk)

## 3.6.0 / 2020-07-13
### Added
* [#458](https://github.com/Dynamoid/dynamoid/pull/458) Added `binary` field type
* [#459](https://github.com/Dynamoid/dynamoid/pull/459) Added `log_formatter` config option and changed default logging format

### Changed
* [#423](https://github.com/Dynamoid/dynamoid/pull/423) Added warning when generated for a field methods override existing ones
* [#429](https://github.com/Dynamoid/dynamoid/pull/429) Added `raise_error` option for `find` method
* [#440](https://github.com/Dynamoid/dynamoid/pull/440) Optimized performance of `first` method when there are only conditions on key attribute in a query (@mrkamel)
* [#445](https://github.com/Dynamoid/dynamoid/pull/445) Support `limit` parameter in `first` method (@mrkamel)
* [#454](https://github.com/Dynamoid/dynamoid/pull/454) Added block argument to `create`/`create!` methods
* [#456](https://github.com/Dynamoid/dynamoid/pull/456) Detect when `find` method requires a range key argument and raise `Dynamoid::Errors::MissingRangeKey` exception if it's missing
* YARD documentation:
  * added missing documentation so now all the public methods are documented
  * hid all the private methods and classes

### Removed
* [#450](https://github.com/Dynamoid/dynamoid/pull/450) Got rid of `null-logger` gem to make Dynamoid dependencies license suitable for commercial use (@yakjuly)

### Fixed
* [#425](https://github.com/Dynamoid/dynamoid/pull/425) Fixed typos in the README.md file (@omarsotillo)
* [#432](https://github.com/Dynamoid/dynamoid/pull/432) Support tables that use "hash_key" as their partition key name (@remomueller)
* [#434](https://github.com/Dynamoid/dynamoid/pull/434) Support tables that have attribute with name "range_value"
* [#453](https://github.com/Dynamoid/dynamoid/pull/453) Fixed issue with using `type` attribute as a GSI hash key

## 3.5.0 / 2020-04-04
### Added
* [#405](https://github.com/Dynamoid/dynamoid/pull/405) Added `update!` class method (@UrsaDK)
* [#408](https://github.com/Dynamoid/dynamoid/pull/408) Added `ActiveSupport` load hook on `Dynamoid` load (@aaronmallen)
* [#422](https://github.com/Dynamoid/dynamoid/pull/422) Added `.pluck` method

### Fixed
* [#410](https://github.com/Dynamoid/dynamoid/pull/410) Fixed creating GSI when table uses on-demand capacity provisioning (@icy-arctic-fox)
* [#414](https://github.com/Dynamoid/dynamoid/pull/414) Fixed lazy table creation
* [#415](https://github.com/Dynamoid/dynamoid/pull/415) Fixed RubyDoc comment (@walkersumida)
* [#420](https://github.com/Dynamoid/dynamoid/pull/420) Fixed `#persisted?` for deleted/destroyed models

### Changed
* [#416](https://github.com/Dynamoid/dynamoid/pull/416) Improved speed of Adapter's `truncate` method. It now uses `#batch_delete_item` method (@TheSmartnik)
* [#421](https://github.com/Dynamoid/dynamoid/pull/421) Added `touch: false` option of the #save method
* [#423](https://github.com/Dynamoid/dynamoid/pull/423) Added warning when generated for a field methods override existing ones

## 3.4.1
### Fixed
* Fix: [#398](https://github.com/Dynamoid/dynamoid/pull/398) Fix broken configuration

## 3.4.0
### Added
* Feature: [#386](https://github.com/Dynamoid/dynamoid/pull/386) Disable timestamps fields on a table level with new
  table option `timestamps`
* Feature: [#387](https://github.com/Dynamoid/dynamoid/pull/387) Add TTL support with table option `expires`
* Feature: [#393](https://github.com/Dynamoid/dynamoid/pull/393) Support pre-configured credentials with new config
  option `credentials` (@emmajhyde)
* Feature: [#397](https://github.com/Dynamoid/dynamoid/pull/397) Configure on-demand table capacity mode with `capacity_mode` option

### Changed
* Improvement: [#388](https://github.com/Dynamoid/dynamoid/pull/388) Minor memory optimization - don't allocate excessive
  hash (@arjes)

### Fixed
* Fix: [#382](https://github.com/Dynamoid/dynamoid/pull/382) Fixed deprecation warning about `Module#parent_name` in Rails 6 (@tmandke)
* Fix: Typos in Readme.md (@romeuhcf)

## 3.3.0
### Added
* [#374](https://github.com/Dynamoid/dynamoid/pull/374) Add `#project` query method to load only specified fields

### Changed
* [#359](https://github.com/Dynamoid/dynamoid/pull/359) Add support of `NULL` and `NOT_NULL` operators
* [#360](https://github.com/Dynamoid/dynamoid/pull/360) Add `store_attribute_with_nil_value` config option
* [#368](https://github.com/Dynamoid/dynamoid/pull/368) Support Rails 6 (RC1)

### Fixed
* [#357](https://github.com/Dynamoid/dynamoid/pull/357) Fix synchronous table creation issue
* [#362](https://github.com/Dynamoid/dynamoid/pull/362) Fix issue with selecting Global Secondary Index (@atyndall)
* [#368](https://github.com/Dynamoid/dynamoid/pull/368) Repair `#previous_changes` method from Dirty API
* [#373](https://github.com/Dynamoid/dynamoid/pull/373) Fix threadsafety of loading `Dynamoid::Adapter` (@tsub)

## 3.2.0
### Added
* [#341](https://github.com/Dynamoid/dynamoid/pull/341), [#342](https://github.com/Dynamoid/dynamoid/pull/342) Add `find_by_pages` method to provide access to DynamoDB query result pagination mechanism (@bmalinconico, @arjes)
* [#354](https://github.com/Dynamoid/dynamoid/pull/354) Add `map` field type

### Changed
* [#340](https://github.com/Dynamoid/dynamoid/pull/340) Improve selecting more optimal GSI for Query operation - choose GSI with sort key if it's used in criteria (@ryz310)
* [#351](https://github.com/Dynamoid/dynamoid/pull/351) Add warnings about nonexistent fields in `where` conditions
* [#352](https://github.com/Dynamoid/dynamoid/pull/352) Add warning about skipped conditions
* [#356](https://github.com/Dynamoid/dynamoid/pull/356) Simplify requiring Rake tasks in non-Rails application
* Readme.md. Minor improvements and Fixed (@cabello)

## 3.1.0
### Added
* [#302](https://github.com/Dynamoid/dynamoid/pull/302) Add methods similar to `ActiveRecord::AttributeMethods::BeforeTypeCast`:
  * method `attributes_before_type_cast`
  * method `read_attribte_before_type_cast`
  * methods `<name>_before_type_cast`
* [#303](https://github.com/Dynamoid/dynamoid/pull/303) Add `#update_attributes!` method
* [#304](https://github.com/Dynamoid/dynamoid/pull/304) Add `inheritance_field` option for `Document.table` method to specify column name for supporting STI and storing class name
* [#305](https://github.com/Dynamoid/dynamoid/pull/305) Add increment/decrement methods:
  * `#increment`
  * `#increment!`
  * `#decrement`
  * `#decrement!`
  * `.inc`
* [#307](https://github.com/Dynamoid/dynamoid/pull/307) Allow to declare type of elements in `array`/`set` fields with `of` option. Only scalar types are supported as well as custom types
* [#312](https://github.com/Dynamoid/dynamoid/pull/312) Add Ability to specify network timeout connection settings (@lulu-ulul)
* [#313](https://github.com/Dynamoid/dynamoid/pull/313) Add support for backoff in scan and query (@bonty)

### Changed
* [#314](https://github.com/Dynamoid/dynamoid/pull/314) Re-implement `count` for `where`-chain query efficiently. So now  `where(...).count` doesn't load all the documents, just statistics

### Fixed
* [#298](https://github.com/Dynamoid/dynamoid/pull/298) Fix `raw` field storing when value is a Hash with non-string keys
* [#299](https://github.com/Dynamoid/dynamoid/pull/299) Fix `raw` fields - skip empty strings and sets
* [#309](https://github.com/Dynamoid/dynamoid/pull/309) Fix loading of a document that contains not declared in model class fields
* [#310](https://github.com/Dynamoid/dynamoid/pull/310) Fix `Adapter#list_tables` method to return names of all tables, not just first page (@knovoselic)
* [#311](https://github.com/Dynamoid/dynamoid/pull/311) Fix `consistent_read` option of `.find` (@kokuyouwind)
* [#319](https://github.com/Dynamoid/dynamoid/pull/319) Repair consistent reading for `find_all`
* [#317](https://github.com/Dynamoid/dynamoid/pull/317) Fix `create_tables` rake task

## 3.0.0
### Changed
* BREAKING [#267](https://github.com/Dynamoid/dynamoid/pull/267) Upgrade AWS SDK to V3
* BREAKING [#268](https://github.com/Dynamoid/dynamoid/pull/268) Drop support of old Ruby versions. Support Ruby since 2.3 version
* BREAKING [#268](https://github.com/Dynamoid/dynamoid/pull/268) Drop support of old Rails versions. Support Rails since 4.2 version
* BREAKING [#278](https://github.com/Dynamoid/dynamoid/pull/278) Add type casting for finders (`find`, `find_by_id` and `find_all`)
* BREAKING [#279](https://github.com/Dynamoid/dynamoid/pull/279) Change default value of `application_timezone` config option from `:local` to `:utc`
* BREAKING [#288](https://github.com/Dynamoid/dynamoid/pull/288) Add `store_boolean_as_native` config option and set it to `true` by default. So all boolean fields are stored not as string `'t'` and `'f'` but as native boolean values now
* BREAKING [#289](https://github.com/Dynamoid/dynamoid/pull/289) Add `dynamodb_timezone` config option and set it to `:utc` by default. So now all `date` and `datetime` fields stored in string format will be converted to UTC time zone by default
* [#261](https://github.com/Dynamoid/Dynamoid/pull/261) Improve documentation (@walkersumida)
* [#264](https://github.com/Dynamoid/Dynamoid/pull/264) Improve documentation (@xbx)
* [#278](https://github.com/Dynamoid/Dynamoid/pull/278) Add Rails-like type casting
* [#281](https://github.com/Dynamoid/Dynamoid/pull/281) Deprecate dynamic finders, `find_all`, `find_by_id`, `find_by_composite_key`, `find_all_by_composite_key` and `find_all_by_secondary_index`
* [#285](https://github.com/Dynamoid/Dynamoid/pull/285) Set timestamps (`created_at` and `updated_at`) in `upsert`, `update_fields`, `import` and `update` methods
* [#286](https://github.com/Dynamoid/Dynamoid/pull/286) Disable scan warning when intentionally loading all items from a collection (@knovoselic)

### Fixed
* Bug: [#275](https://github.com/Dynamoid/Dynamoid/pull/275) Fix custom type serialization/deserialization
* Bug: [#283](https://github.com/Dynamoid/Dynamoid/pull/283) Fix using string formats for partition and sort keys of `date`/`datetime` type
* Bug: [#283](https://github.com/Dynamoid/Dynamoid/pull/283) Fix type declaration of custom type fields. Returned by `.dynamoid_field_type` value is treated as Dynamoid's type now
* Bug: [#287](https://github.com/Dynamoid/Dynamoid/pull/287) Fix logging disabling (@ghiculescu)

## 2.2.0
### Changed
* Feature: [#256](https://github.com/Dynamoid/Dynamoid/pull/256) Support Rails 5.2 (@andrykonchin)

### Fixed
* Bug: [#255](https://github.com/Dynamoid/Dynamoid/pull/255) Fix Vagrant RVM configuration and upgrade to Ruby 2.4.1 (@richardhsu)

## 2.1.0
### Changed
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

### Fixed
* Bug: [#216](https://github.com/Dynamoid/Dynamoid/pull/216) Fix global index detection in queries with conditions other than equal (@andrykonchin)
* Bug: [#224](https://github.com/Dynamoid/Dynamoid/pull/224) Fix how `contains` operator works with `set` and `array` field types (@andrykonchin)
* Bug: [#225](https://github.com/Dynamoid/Dynamoid/pull/225) Fix equal conditions for `array` fields (@andrykonchin)
* Bug: [#229](https://github.com/Dynamoid/Dynamoid/pull/229) Repair support `start` chain method on Scan operation (@mnussbaumer)
* Bug: [#238](https://github.com/Dynamoid/Dynamoid/pull/238) Fix default value of `models_dir` config option (@baloran)
* Bug: [#244](https://github.com/Dynamoid/Dynamoid/pull/244) Allow to pass empty strings and sets to `.import` (@andrykonchin)
* Bug: [#246](https://github.com/Dynamoid/Dynamoid/pull/246) Batch operations (`batch_write_item` and `batch_read_item`) handle unprocessed items themselves (@andrykonchin)
* Bug: [#250](https://github.com/Dynamoid/Dynamoid/pull/250) Update outdated warning message about inefficient query and missing indices (@andrykonchin)
* Bug: [252](https://github.com/Dynamoid/Dynamoid/pull/252) Don't loose nanoseconds when store DateTime as float number

## 2.0.0
Breaking changes in this release generally bring Dynamoid behavior closer to the Rails-way.

### Added
* [#199](https://github.com/Dynamoid/Dynamoid/pull/199) Added `Document.import` method (@andrykonchin)
* [#212](https://github.com/Dynamoid/Dynamoid/pull/212) Add foreign_key option (@andrykonchin)
* [#213](https://github.com/Dynamoid/Dynamoid/pull/213) Support Boolean raw type (@andrykonchin)

### Changed
* BREAKING [#186](https://github.com/Dynamoid/Dynamoid/pull/186) Consistent behavior for `Model.where({}).all` (@andrykonchin)
  * <= 1.3.x behaviour -
    * load lazily if user specified batch size
    * load all collection into memory otherwise
  * New behaviour -
    * always return lazy evaluated collection
    * It means Model.where({}).all returns Enumerator instead of Array.
    * If you need Array interface you have to convert collection to Array manually with to_a method call
* BREAKING [#195](https://github.com/Dynamoid/Dynamoid/pull/195) Failed `#find` returns error (@andrykonchin)
  * <= 1.3.x behaviour - find returns nil or smaller array.
  * New behaviour - it raises RecordNotFound if one or more records can not be found for the requested ids
* BREAKING [#196](https://github.com/Dynamoid/Dynamoid/pull/196) Return value of `#save` (@andrykonchin)
  * <= 1.3.x behaviour - save returns self if model is saved successfully
  * New behaviour - it returns true
* [#185](https://github.com/Dynamoid/Dynamoid/pull/185) `where`, finders and friends take into account STI (single table inheritance) now (@andrykonchin)
    * query will return items of the model class and all subclasses
* [#190](https://github.com/Dynamoid/Dynamoid/pull/190) Allow passing options to range when defining attributes of the document (@richardhsu)
    * Allows for serialized fields and passing the serializer option.
* [#198](https://github.com/Dynamoid/Dynamoid/pull/198) Enhanced `#create` and `#create!` to allow multiple document creation like `#import` (@andrykonchin)
    * `User.create([{name: 'Josh'}, {name: 'Nick'}])`
* [#205](https://github.com/Dynamoid/Dynamoid/pull/205) Use batch deletion via `batch_write_item` for `delete_all` (@andrykonchin)
* [#205](https://github.com/Dynamoid/Dynamoid/pull/205) Rename `Chain#destroy_all` as `Chain#delete_all`, to better match Rails conventions when no callbacks are run (@andrykonchin)
    * kept the old name as an alias, for backwards compatibility
* [#207](https://github.com/Dynamoid/Dynamoid/pull/207) Added slicing by 25 requests in #batch_write_item (@andrykonchin)
* [#211](https://github.com/Dynamoid/Dynamoid/pull/211) Improved Vagrant setup for testing (@richardhsu)
* Improved Documentation (@pboling, @andrykonchin)

### Fixed
* [#191](https://github.com/Dynamoid/Dynamoid/pull/191), [#192](https://github.com/Dynamoid/Dynamoid/pull/192) Support lambdas as fix for value types were not able to be used as default values (@andrykonchin)(@richardhsu)
* [#202](https://github.com/Dynamoid/Dynamoid/pull/202) Fix several issues with associations (@andrykonchin)
    * setting `nil` value raises an exception
    * document doesn't keep assigned model and loads it from the storage
    * delete call doesn't update cached ids of associated models
    * fix clearing old `has_many` association while add model to new `has_many` association
* [#204](https://github.com/Dynamoid/Dynamoid/pull/204) Fixed issue where `Document.where(:"id.in" => [])` would do `Query` operation instead of `Scan` (@andrykonchin)
    * Fixed `Chain#key_present?`
* [#205](https://github.com/Dynamoid/Dynamoid/pull/205) Fixed `delete_all` (@andrykonchin)
    * Fixed exception when makes scan and sort key is declared in model
    * Fixed exception when makes scan and any condition is specified in where clause (like Document.where().delete_all)
    * Fixed exception when makes query and sort key isn't declared in model
* [#207](https://github.com/Dynamoid/Dynamoid/pull/207) Fixed `#delete` method for case `adapter.delete(table_name, [1, 2, 3], range_key: 1)` (@andrykonchin)

## 1.3.4
### Added
* Added `Chain#last` method (@andrykonchin)
* Added `date` field type (@andrykonchin)
* Added `application_timezone` config option (@andrykonchin)
* Support condition operators for non-key fields for Query request (@andrykonchin)
* Support condition operators for Scan request (@andrykonchin)
* Support additional operators `in`, `contains`, `not_contains` (@andrykonchin)
* Support type casting in `where` clause (@andrykonchin)
* Allow consistent reading for Scan request (@andrykonchin)
* Add `Chain#scan_limit` (@richardhsu)
* Support batch loading for Query requests (@richardhsu)
* Support querying Global/Local Secondary Indices in `where` clause (@richardhsu)

### Changed
* Use Query instead of Scan if there are no conditions for sort (range) key in where clause (@andrykonchin)
* Rename `Chain#eval_limit` to `#record_limit` (@richardhsu)
* Only query on GSI if projects all attributes in `where` clause (@richardhsu)

### Fixed
* Fix incorrect applying of default field value (#36 and #117, @andrykonchin)
* Fix sync table creation/deletion (#160, @mirokuxy)
* Allow to override document timestamps (@andrykonchin)
* Fix storing empty array as nil (#8, @andrykonchin)
* Fix `limit` handling for Query requests (#85, @richardhsu)
* Fix `limit` handling for Scan requests (#85, @richardhsu)
* Fix paginating for Query requests (@richardhsu)
* Fix paginating for Scan requests (@richardhsu)
* Fix `batch_get_item` method call for integer partition key (@mudasirraza)

## 1.3.3
### Added
* Allow configuration of the Dynamoid models directory, as not everyone keeps non AR models in app/models
  - Dynamoid::Config.models_dir = "app/whatever"

## 1.3.2
### Fixed
* Fix migrations by stopping the loading of all rails models outside the rails env.

## 1.3.1
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

## 1.3.0
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

## 1.2.1
* Remove accidental Gemfile.lock; fix .gitignore (#95, @pboling)
* Allow options to put_items (#95, @alexperto)
* Support range key in secondary index queries (#95, @pboling)
* Better handling of options generally (#95, @pboling)
* Support for batch_delete_item API (#95, @pboling)
* Support for batch_write_item API (#95, @alexperto)

## 1.2.0
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

## 1.1.0
* Added support for optimistic locking on delete (PR #29, @sumocoder)
* upgrade concurrent-ruby requirement to 1.0 (PR #31, @keithmgould)

## 1.0.0
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
