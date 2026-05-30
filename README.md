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

Dynamoid is an ORM for Amazon's DynamoDB for Ruby applications. It
provides similar functionality to ActiveRecord and improves on Amazon's
existing
[HashModel](http://docs.amazonwebservices.com/AWSRubySDK/latest/AWS/Record/HashModel.html)
by providing better searching tools and native association support.

DynamoDB is not like other document-based databases you might know, and
is very different indeed from relational databases. It sacrifices
anything beyond the simplest relational queries and transactional
support to provide a fast, cost-efficient, and highly durable storage
solution. If your database requires complicated relational queries
then this modest Gem cannot provide them for you
and neither can DynamoDB. In those cases you would do better to look
elsewhere for your database needs.

But if you want a fast, scalable, simple, easy-to-use database (and a
Gem that supports it) then look no further!

## Installation

Installing Dynamoid is pretty simple. First include the Gem in your
Gemfile:

```ruby
gem 'dynamoid'
```
## Prerequisites

Dynamoid depends on the aws-sdk, and this is tested on the current
version of aws-sdk (~> 3), rails (>= 4). Hence the configuration as
needed for aws to work will be dealt with by aws setup.

### AWS SDK Version Compatibility

Make sure you are using the version for the right AWS SDK.

| Dynamoid version | AWS SDK Version |
| ---------------- | --------------- |
| 0.x              | 1.x             |
| 1.x              | 2.x             |
| 2.x              | 2.x             |
| 3.x              | 3.x             |


### Ruby & Rails Compatibility

Dynamoid supports Ruby >= 2.3 and Rails >= 4.2.

Its compatibility is tested against following Ruby versions: 2.3, 2.4,
2.5, 2.6, 2.7, 3.0, 3.1, 3.2, 3.3, 3.4, and 4.0, JRuby 9.4.x and against Rails versions: 4.2, 5.0, 5.1,
5.2, 6.0, 6.1, 7.0, 7.1, 7.2, 8.0, and 8.1.

## Setup

You *must* include `Dynamoid::Document` in every Dynamoid model.

```ruby
class User
  include Dynamoid::Document

  # fields declaration
end
```


## Credits

Dynamoid borrows code, structure, and even its name very liberally from
the truly amazing [Mongoid](https://github.com/mongoid/mongoid). Without
Mongoid to crib from none of this would have been possible, and I hope
they don't mind me reusing their very awesome ideas to make DynamoDB
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


## Security

See [SECURITY.md][security].


## License

The gem is available as open source under the terms of
the [MIT License][license] [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)][license-ref].
See [LICENSE][license] for the official [Copyright Notice][copyright-notice-explainer].

[copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year

[license]: https://github.com/Dynamoid/dynamoid/blob/master/LICENSE.txt

[license-ref]: https://opensource.org/licenses/MIT

[security]: https://github.com/Dynamoid/dynamoid/blob/master/SECURITY.md

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
