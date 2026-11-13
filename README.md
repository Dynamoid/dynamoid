# Dynamoid

[![Gem Version][⛳️version-img]][⛳️gem]
[![Supported Build Status][🏘sup-wf-img]][🏘sup-wf]
[![Maintainability][⛳cclim-maint-img♻️]][⛳cclim-maint]
[![Coveralls][🏘coveralls-img]][🏘coveralls]
[![CodeCov][🖇codecov-img♻️]][🖇codecov]
[![Helpers][🖇triage-help-img]][🖇triage-help]
[![Contributors][🖐contributors-img]][🖐contributors]
[![RubyDoc.info][🚎yard-img]][🚎yard]
[![License][🖇src-license-img]][🖇src-license]
[![GitMoji][🖐gitmoji-img]][🖐gitmoji]
[![SemVer 2.0.0][🧮semver-img]][🧮semver]
[![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]
[![Sponsor Project][🖇sponsor-img]][🖇sponsor]

Dynamoid is an Object-Document Mapper (ODM) for Amazon DynamoDB written in Ruby. It provides a familiar Active Record interface for Rails and standalone applications, letting you model, validate, and query DynamoDB items as expressive Ruby objects instead of raw AWS SDK parameter hashes.

## Key Features

Dynamoid combines the familiar ergonomics of Rails' Active Record with the unique power of Amazon DynamoDB:

* *Active Record fidelity* — declare models, associations, validations, callbacks, dirty tracking, optimistic locking, and STI following standard Rails conventions.
* *Convention over configuration* — automatic table naming, UUID partition keys, and automatic timestamps so models work out of the box with minimal setup.
* *Query interface* — chain queries using ActiveRecord syntax while Dynamoid automatically routes to fast Query operations and selects secondary indexes over full-table Scans.
* *Native DynamoDB mutations* — perform atomic in-place updates on numbers and collections, conditional writes, and high-throughput bulk imports.
* *ACID transactions* — coordinate all-or-nothing reads and writes across multiple items and tables with full transactional guarantees.
* *Transparent attribute serialization* — persist types not native to DynamoDB (`Date`, `DateTime`), serialize objects into strings (YAML by default), and support custom classes implementing dump and load methods.

## Quick Start

### Installation

Add Dynamoid to your `Gemfile`:

```ruby
gem 'dynamoid'
```

Or install it with Bundler:

```shell
bundle add dynamoid
```

### Configuration

Configure Dynamoid in `config/initializers/dynamoid.rb` (for Rails) or during application setup.

For local development and testing without an AWS account, point Dynamoid to [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html):

```ruby
require 'dynamoid'

Dynamoid.configure do |config|
  config.namespace  = "my_app_#{defined?(Rails) ? Rails.env : 'development'}"
  config.endpoint   = 'http://localhost:8000'
  config.region     = 'us-east-1'
  config.access_key = 'fake'
  config.secret_key = 'fake'
end
```

When connecting to Amazon DynamoDB, credentials and region are discovered automatically from environment variables, AWS profiles, or IAM roles:

```ruby
Dynamoid.configure do |config|
  config.namespace = "my_app_#{Rails.env}"
end
```

### Defining a Model

Include `Dynamoid::Document` in your model class and declare attributes with `field`:

```ruby
class Order
  include Dynamoid::Document

  field :customer_id
  field :status, :string, default: 'pending'
  field :amount, :number, default: 0

  validates :customer_id, presence: true

  before_save { self.status = status.downcase }
end
```

By default, the table name is derived from the pluralized class name (`orders`), the primary key is an auto-generated string UUID named `id`, and timestamps (`created_at`, `updated_at`) are maintained automatically.

### Usage

#### Active Record CRUD

```ruby
order = Order.create(customer_id: 'cust_101', amount: 95)
order = Order.find(order.id)
order.status = 'processing'
order.save
order.update_attributes(status: 'completed')
order.destroy
```

#### Querying

```ruby
pending = Order.where(status: 'pending').all
recent  = Order.where(customer_id: 'cust_101', 'created_at.gte': 1.day.ago).all
```

#### Atomic In-Place Updates

```ruby
order = Order.find(order_id)
order.update(if: { status: 'processing' }) do |updater|
  updater.set status: 'completed'
  updater.add amount: 10
end
```

#### ACID Transactions

```ruby
order = Order.find(order_id)

Order.transaction do |t|
  t.update_attributes(order, status: 'archived')
  t.create(Order, customer_id: 'cust_102', amount: 50)
end
```

## Documentation

Comprehensive documentation is available on the project documentation site:

* [User Guides](https://dynamoid.github.io/dynamoid/guides/) — In-depth guides covering schema modeling, querying, persistence, transactions, and operational configuration.
* [API Reference](https://dynamoid.github.io/dynamoid/reference/) — Complete class and method reference generated from source code documentation.

## Compatibility

Dynamoid requires `aws-sdk-dynamodb` (AWS SDK v3) and `activemodel` (>= 4.2).

Continuous integration tests actively verify correctness against:
* Ruby: 2.3 – 4.0 (including JRuby 10.x)
* Rails / ActiveModel: 4.2 – 8.1

## Contributing

Please see [CONTRIBUTING.md][contributing] for details on how to get started.

## Security

Please see [SECURITY.md][security] for vulnerability reporting guidelines.

## License

The gem is available as open source under the terms of the [MIT License][license] [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)][license-ref].
See [LICENSE][license] for the official [Copyright Notice][copyright-notice-explainer].

## Credits

Dynamoid was originally created in 2012 by [Josh Symonds](https://github.com/joshsymonds) ([original repository](https://github.com/joshsymonds/Dynamoid)). Historical issues and discussions prior to the project's migration in 2015 can still be found in the [legacy issue tracker](https://github.com/joshsymonds/Dynamoid/issues).

Dynamoid borrows code, structure, and even its name very liberally from
the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without
Mongoid to crib from none of this would have been possible, and I hope
they don't mind me reusing their very awesome ideas to make Amazon DynamoDB
just as accessible to the Ruby world as MongoDB.

Also, without contributors the project wouldn't be nearly as awesome. So
many thanks to:

* [Chris Hobbs](https://github.com/ckhsponge)
* [Logan Bowers](https://github.com/loganb)
* [Lane LaRue](https://github.com/luxx)
* [Craig Heneveld](https://github.com/cheneveld)
* [Anantha Kumaran](https://github.com/ananthakumaran)
* [Jason Dew](https://github.com/jasondew)
* [Luis Arias](https://github.com/luisantonioa)
* [Stefan Neculai](https://github.com/stefanneculai)
* [Philip White](https://github.com/philipmw) *
* [Peeyush Kumar](https://github.com/peeyush1234)
* [Sumanth Ravipati](https://github.com/sumocoder)
* [Pascal Corpet](https://github.com/pcorpet)
* [Brian Glusman](https://github.com/bglusman) *
* [Peter Boling](https://github.com/pboling) *
* [Andrew Konchin](https://github.com/andrykonchin) *

\* Current Maintainers


[contributing]:
https://github.com/Dynamoid/dynamoid/blob/master/CONTRIBUTING.md
[security]: https://github.com/Dynamoid/dynamoid/blob/master/SECURITY.md
[license]: https://github.com/Dynamoid/dynamoid/blob/master/LICENSE.txt
[license-ref]: https://opensource.org/licenses/MIT
[copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year

[⛳️gem]: https://rubygems.org/gems/dynamoid
[⛳️version-img]: http://img.shields.io/gem/v/dynamoid.svg
[⛳cclim-maint]: https://codeclimate.com/github/Dynamoid/dynamoid/maintainability
[⛳cclim-maint-img♻️]: https://api.codeclimate.com/v1/badges/27fd8b6b7ff338fa4914/maintainability
[🏘coveralls]: https://coveralls.io/github/Dynamoid/dynamoid?branch=master
[🏘coveralls-img]: https://coveralls.io/repos/github/Dynamoid/dynamoid/badge.svg?branch=master
[🖇codecov]: https://codecov.io/gh/Dynamoid/dynamoid
[🖇codecov-img♻️]: https://codecov.io/gh/Dynamoid/dynamoid/branch/master/graph/badge.svg?token=84WeeoxaN9
[🖇src-license]: https://github.com/Dynamoid/dynamoid/blob/master/LICENSE.txt
[🖇src-license-img]: https://img.shields.io/badge/License-MIT-green.svg
[🖐gitmoji]: https://gitmoji.dev
[🖐gitmoji-img]: https://img.shields.io/badge/gitmoji-3.9.0-FFDD67.svg?style=flat
[🚎yard]: https://www.rubydoc.info/gems/dynamoid
[🚎yard-img]: https://img.shields.io/badge/yard-docs-blue.svg?style=flat
[🧮semver]: http://semver.org/
[🧮semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[🖐contributors]: https://github.com/Dynamoid/dynamoid/graphs/contributors
[🖐contributors-img]: https://img.shields.io/github/contributors-anon/Dynamoid/dynamoid
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat
[🖇sponsor-img]: https://img.shields.io/opencollective/all/dynamoid
[🖇sponsor]: https://opencollective.com/dynamoid
[🖇triage-help]: https://www.codetriage.com/dynamoid/dynamoid
[🖇triage-help-img]: https://www.codetriage.com/dynamoid/dynamoid/badges/users.svg
[🏘sup-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ci.yml?query=branch%3Amaster
[🏘sup-wf-img]: https://github.com/Dynamoid/dynamoid/actions/workflows/ci.yml/badge.svg?branch=master
