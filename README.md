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


A feature-rich and powerful Ruby ORM for Amazon DynamoDB, designed to provide a familiar ActiveRecord-like experience for Ruby applications.


## Key Features

* ActiveRecord-style DSL: Implements an interface and configuration similar to Rails' ActiveRecord.
* Querying & Persistence: Provides methods for finding, querying, and updating models.
* Advanced ORM Features: Supports associations, callbacks, validations, Dirty API, optimistic locking, and type casting.
* Additional Attribute Types: Supports types not natively provided by Amazon DynamoDB, such as `DateTime`, `Time`, and more.
* Transactions: Supports Amazon DynamoDB transactional operations.


## Quick start


### Installation

Add Dynamoid to your `Gemfile`:

```ruby
gem 'dynamoid'
```

Or install it using `bundle`:

```shell
bundle add dynamoid
```

Alternatively, you can install the gem manually:

```shell
gem install dynamoid
```


### Usage

To define a model, include `Dynamoid::Document` and declare your fields. Dynamoid supports ActiveModel validations and automatic timestamps:

```ruby
class User
  include Dynamoid::Document

  field :name                        # Type defaults to :string
  field :email
  field :age, :integer
  field :active, :boolean, default: true

  validates :name, presence: true
  validates :email, format: { with: /@/ }
end
```

Once defined, you can interact with your models using a familiar API:

```ruby
# Create and Save
user = User.create(name: 'Josh', email: 'josh@example.com')

# Find and Update
user = User.where(email: 'josh@example.com').first
user.update_attributes(age: 30)

# Querying
users = User.where(active: true).all.to_a
```


### Essential Configuration

Minimal connection settings are required. You can configure Dynamoid in several ways, such as in `config/initializers/dynamoid.rb` (for Rails) or directly in your setup:

```ruby
require 'dynamoid'

Dynamoid.configure do |config|
  config.access_key = 'REPLACE_WITH_ACCESS_KEY_ID'
  config.secret_key = 'REPLACE_WITH_SECRET_ACCESS_KEY'
  config.region = 'REPLACE_WITH_REGION' # e.g. 'us-west-2'
end
```


## Documentation

* **API Reference:** Comprehensive documentation for all classes and methods is available on [RubyDoc.info](https://www.rubydoc.info/github/Dynamoid/dynamoid/).
* **User Guides:** For detailed overviews and usage examples of specific features, see the online [User Guides](https://dynamoid.github.io/dynamoid/guides/).


## Compatibility

Dynamoid relies on `aws-sdk-dynamodb` (AWS SDK v3) and `activemodel` (>= 4.2). It officially supports Ruby >= 2.3 and Rails >= 4.2.

Compatibility is tested against the following versions:
* Ruby: 2.3 - 4.0 (including JRuby 10.x)
* Rails: 4.2 - 8.1


## Contributing

We welcome contributions to Dynamoid! Please see our [CONTRIBUTING.md][contributing] guide for details on how to get started. Join us!


## Security

See [SECURITY.md][security].


## License

The gem is available as open source under the terms of
the [MIT License][license] [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)][license-ref].
See [LICENSE][license] for the official [Copyright Notice][copyright-notice-explainer].


## Credits

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
