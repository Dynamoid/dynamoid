<a href="https://github.com/Dynamoid"><img alt="Dynamoid Logo by GitHub" src="https://github.com/Dynamoid.png?size=192" width="14%" align="right"/></a>

# 💎 Dynamoid

[![Version][👽versioni]][👽version] [![Ruby Users Forum][✉️ruby-forum-top-img]][✉️ruby-forum] [![GitHub tag (latest SemVer)][⛳️tag-img]][⛳️tag] [![License: MIT][📄license-img]][📄license] [![Total downloads][👽dl-ranki]][👽dl-rank] [![CodeCov Test Coverage][🏀codecovi]][🏀codecov] [![Coveralls Test Coverage][🏀coveralls-img]][🏀coveralls] [![QLTY Test Coverage][🏀qlty-covi]][🏀qlty-cov] [![QLTY Maintainability][🏀qlty-mnti]][🏀qlty-mnt] [![CI Heads][🚎3-hd-wfi]][🚎3-hd-wf] [![CI Runtime Dependencies @ HEAD][🚎12-crh-wfi]][🚎12-crh-wf] [![CI Current][🚎11-c-wfi]][🚎11-c-wf] [![CI Truffle Ruby][🚎9-t-wfi]][🚎9-t-wf] [![CI JRuby][🚎10-j-wfi]][🚎10-j-wf] [![Deps Locked][🚎13-🔒️-wfi]][🚎13-🔒️-wf] [![Deps Unlocked][🚎14-🔓️-wfi]][🚎14-🔓️-wf] [![CI Test Coverage][🚎2-cov-wfi]][🚎2-cov-wf] [![CI Style][🚎5-st-wfi]][🚎5-st-wf] [![Apache SkyWalking Eyes License Compatibility Check][🚎15-🪪-wfi]][🚎15-🪪-wf]

`if ci_badges.map(&:color).detect { it != "green"}` ☝️ [let me know on Discord][✉️discord-invite] or [RubyForum][✉️ruby-forum], as I may have missed the notification.

---

`if ci_badges.map(&:color).all? { it == "green"}` 👇️ send money so I can do more of this. FLOSS maintenance is now my full-time job.

[![OpenCollective Backers][🖇osc-backers-i]][🖇osc-backers] [![OpenCollective Sponsors][🖇osc-sponsors-i]][🖇osc-sponsors] [![Sponsor Me on Github][🖇sponsor-img]][🖇sponsor] [![Liberapay Goal Progress][⛳liberapay-img]][⛳liberapay] [![Donate on PayPal][🖇paypal-img]][🖇paypal] [![Buy me a coffee][🖇buyme-small-img]][🖇buyme] [![Donate at ko-fi.com][🖇kofi-img]][🖇kofi]

<details markdown="1">
 <summary>👣 How will this project approach the September 2025 hostile takeover of RubyGems? 🚑️</summary>

I've summarized my thoughts in [this blog post](https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo).

</details>

## 🌻 Synopsis <a href="https://discord.gg/3qme4XHNKN"><img alt="Galtzo FLOSS Logo by Aboling0, CC BY-SA 4.0" src="https://logos.galtzo.com/assets/images/galtzo-floss/avatar-128px.svg" width="8%" align="right"/></a> <a href="https://ruby-toolbox.com"><img alt="ruby-lang Logo, Yukihiro Matsumoto, Ruby Visual Identity Team, CC BY-SA 2.5" src="https://logos.galtzo.com/assets/images/ruby-lang/avatar-128px.svg" width="8%" align="right"/></a>

Dynamoid is a feature-rich Ruby ORM for Amazon DynamoDB, designed to provide
a familiar ActiveRecord-like experience for Ruby applications.

### Key Features

* ActiveRecord-style DSL: Implements an interface and configuration similar to Rails' ActiveRecord.
* Querying & Persistence: Provides methods for finding, querying, and updating models.
* Advanced ORM Features: Supports associations, callbacks, validations, Dirty API, optimistic locking, and type casting.
* Additional Attribute Types: Supports types not natively provided by Amazon DynamoDB, such as `DateTime`, `Time`, and more.
* Transactions: Supports Amazon DynamoDB transactional operations.

## 💡 Info you can shake a stick at

| Tokens to Remember | [![Gem name][⛳️name-img]][⛳️gem-name] [![Gem namespace][⛳️namespace-img]][⛳️gem-namespace] |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Works with JRuby | [![JRuby 9.2 Compat][💎jruby-9.2i]][🚎jruby-9.2-wf] [![JRuby 9.3 Compat][💎jruby-9.3i]][🚎jruby-9.3-wf] <br/> [![JRuby 9.4 Compat][💎jruby-9.4i]][🚎jruby-9.4-wf] [![JRuby 10.0 Compat][💎jruby-10.0i]][🚎jruby-10.0-wf] [![JRuby current Compat][💎jruby-c-i]][🚎10-j-wf] [![JRuby HEAD Compat][💎jruby-headi]][🚎3-hd-wf]|
| Works with Truffle Ruby | [![Truffle Ruby 22.3 Compat][💎truby-22.3i]][🚎truby-22.3-wf] [![Truffle Ruby 23.0 Compat][💎truby-23.0i]][🚎truby-23.0-wf] [![Truffle Ruby 23.1 Compat][💎truby-23.1i]][🚎truby-23.1-wf] <br/> [![Truffle Ruby 24.2 Compat][💎truby-24.2i]][🚎truby-24.2-wf] [![Truffle Ruby 25.0 Compat][💎truby-25.0i]][🚎truby-25.0-wf] [![Truffle Ruby 33.0 Compat][💎truby-33.0i]][🚎truby-33.0-wf] [![Truffle Ruby current Compat][💎truby-c-i]][🚎9-t-wf] [![Truffle Ruby HEAD Compat][💎truby-headi]][🚎3-hd-wf]|
| Works with MRI Ruby 4 | [![Ruby current Compat][💎ruby-c-i]][🚎11-c-wf] [![Ruby HEAD Compat][💎ruby-headi]][🚎3-hd-wf]|
| Works with MRI Ruby 3 | [![Ruby 3.0 Compat][💎ruby-3.0i]][🚎ruby-3.0-wf] [![Ruby 3.1 Compat][💎ruby-3.1i]][🚎ruby-3.1-wf] [![Ruby 3.2 Compat][💎ruby-3.2i]][🚎ruby-3.2-wf] [![Ruby 3.3 Compat][💎ruby-3.3i]][🚎ruby-3.3-wf] [![Ruby 3.4 Compat][💎ruby-3.4i]][🚎ruby-3.4-wf]|
| Works with MRI Ruby 2 | ![Ruby 2.3 Compat][💎ruby-2.3i] <br/> [![Ruby 2.4 Compat][💎ruby-2.4i]][🚎ruby-2.4-wf] [![Ruby 2.5 Compat][💎ruby-2.5i]][🚎ruby-2.5-wf] [![Ruby 2.6 Compat][💎ruby-2.6i]][🚎ruby-2.6-wf] [![Ruby 2.7 Compat][💎ruby-2.7i]][🚎ruby-2.7-wf]|
| Support & Community | [![Join Me on Daily.dev's RubyFriends][✉️ruby-friends-img]][✉️ruby-friends] [![Get help from RubyForum][✉️ruby-forum-img]][✉️ruby-forum] [![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite] [![Get help from me on Upwork][👨🏼‍🏫expsup-upwork-img]][👨🏼‍🏫expsup-upwork] [![Get help from me on Codementor][👨🏼‍🏫expsup-codementor-img]][👨🏼‍🏫expsup-codementor] |
| Source | [![Source on GitLab.com][📜src-gl-img]][📜src-gl] [![Source on CodeBerg.org][📜src-cb-img]][📜src-cb] [![Source on GitHub.com][📜src-gh-img]][📜src-gh] [![The best SHA: dQw4w9WgXcQ!][🧮kloc-img]][🧮kloc] |
| Documentation | [![Current release on RubyDoc.info][📜docs-cr-rd-img]][🚎yard-current] [![YARD on Galtzo.com][📜docs-head-rd-img]][🚎yard-head] [![Maintainer Blog][🚂maint-blog-img]][🚂maint-blog] [![GitLab Wiki][📜gl-wiki-img]][📜gl-wiki] [![GitHub Wiki][📜gh-wiki-img]][📜gh-wiki] |
| Compliance | [![License: MIT][📄license-img]][📄license] [![Apache license compatibility: Category A][📄license-compat-img]][📄license-compat] [![📄ilo-declaration-img]][📄ilo-declaration] [![Security Policy][🔐security-img]][🔐security] [![Contributor Covenant 2.1][🪇conduct-img]][🪇conduct] [![SemVer 2.0.0][📌semver-img]][📌semver] |
| Style | [![Enforced Code Style Linter][💎rlts-img]][💎rlts] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog] [![Gitmoji Commits][📌gitmoji-img]][📌gitmoji] [![Compatibility appraised by: appraisal2][💎appraisal2-img]][💎appraisal2] |
| Maintainer 🎖️ | [![Follow Me on LinkedIn][💖🖇linkedin-img]][💖🖇linkedin] [![Follow Me on Ruby.Social][💖🐘ruby-mast-img]][💖🐘ruby-mast] [![Follow Me on Bluesky][💖🦋bluesky-img]][💖🦋bluesky] [![Contact Maintainer][🚂maint-contact-img]][🚂maint-contact] [![My technical writing][💖💁🏼‍♂️devto-img]][💖💁🏼‍♂️devto] |
| `...` 💖 | [![Find Me on WellFound:][💖✌️wellfound-img]][💖✌️wellfound] [![Find Me on CrunchBase][💖💲crunchbase-img]][💖💲crunchbase] [![My LinkTree][💖🌳linktree-img]][💖🌳linktree] [![More About Me][💖💁🏼‍♂️aboutme-img]][💖💁🏼‍♂️aboutme] [🧊][💖🧊berg] [🐙][💖🐙hub] [🛖][💖🛖hut] [🧪][💖🧪lab] |

### Compatibility

Compatible with MRI Ruby 2.3.0+, and concordant releases of JRuby, and TruffleRuby.
CI workflows and Appraisals are generated for MRI Ruby 2.4+.
This test floor is configured by `ruby.test_minimum` in `.kettle-jem.yml` and
may be higher than the gem's runtime compatibility floor when legacy Rubies are
not practical for the current toolchain.

<a href="https://github.com/kettle-dev"><img alt="kettle-dev Logo by Aboling0, CC BY-SA 4.0" src="https://logos.galtzo.com/assets/images/kettle-dev/avatar-128px.svg" width="14%" align="right"/></a>

The _amazing_ test matrix is powered by the kettle-dev stack.

<details markdown="1">
<summary>How kettle-dev manages complexity in tests</summary>

| Gem | Source | Role | Total downloads |
|-----|--------|------|---------------------|
| [appraisal2](https://clickgems.clickhouse.com/dashboard/appraisal2) | [GitHub](https://github.com/appraisal-rb/appraisal2) | multi-dependency Appraisal matrix generation | [![Total downloads for appraisal2](https://img.shields.io/gem/dt/appraisal2.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/appraisal2) |
| [appraisal2-rubocop](https://clickgems.clickhouse.com/dashboard/appraisal2-rubocop) | [GitHub](https://github.com/appraisal-rb/appraisal2-rubocop) | RuboCop Appraisal generator integration | [![Total downloads for appraisal2-rubocop](https://img.shields.io/gem/dt/appraisal2-rubocop.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/appraisal2-rubocop) |
| [kettle-dev](https://clickgems.clickhouse.com/dashboard/kettle-dev) | [GitHub](https://github.com/kettle-dev/kettle-dev) | development, release, and CI workflow tooling | [![Total downloads for kettle-dev](https://img.shields.io/gem/dt/kettle-dev.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-dev) |
| [kettle-jem](https://clickgems.clickhouse.com/dashboard/kettle-jem) | [GitHub](https://github.com/kettle-dev/kettle-jem) | Appraisals & CI workflow templates | [![Total downloads for kettle-jem](https://img.shields.io/gem/dt/kettle-jem.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-jem) |
| [kettle-soup-cover](https://clickgems.clickhouse.com/dashboard/kettle-soup-cover) | [GitHub](https://github.com/kettle-dev/kettle-soup-cover) | SimpleCov coverage policy and reporting | [![Total downloads for kettle-soup-cover](https://img.shields.io/gem/dt/kettle-soup-cover.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-soup-cover) |
| [kettle-test](https://clickgems.clickhouse.com/dashboard/kettle-test) | [GitHub](https://github.com/kettle-dev/kettle-test) | standard test runner and coverage harness | [![Total downloads for kettle-test](https://img.shields.io/gem/dt/kettle-test.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/kettle-test) |
| [rubocop-lts](https://clickgems.clickhouse.com/dashboard/rubocop-lts) | [GitHub](https://github.com/rubocop-lts/rubocop-lts) | Ruby-version-aware linting | [![Total downloads for rubocop-lts](https://img.shields.io/gem/dt/rubocop-lts.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/rubocop-lts) |
| [turbo_tests2](https://clickgems.clickhouse.com/dashboard/turbo_tests2) | [GitHub](https://github.com/galtzo-floss/turbo_tests2) | parallel test execution | [![Total downloads for turbo_tests2](https://img.shields.io/gem/dt/turbo_tests2.svg?style=flat-square)](https://clickgems.clickhouse.com/dashboard/turbo_tests2) |

</details>

### Federated DVCS

<details markdown="1">
 <summary>Find this repo on federated forges (Coming soon!)</summary>

| Federated [DVCS][💎d-in-dvcs] Repository | Status | Issues | PRs | Wiki | CI |
|-------------------------------------------------|-------------------------------------------|-------------------|------------------|-----------------|----------------|
| 🧪 [Dynamoid/dynamoid on GitLab][📜src-gl] | The Truth | [💚][🤝gl-issues] | [💚][🤝gl-pulls] | [💚][📜gl-wiki] | 🐭 Tiny Matrix |
| 🧊 [Dynamoid/dynamoid on CodeBerg][📜src-cb] | An Ethical Mirror ([Donate][🤝cb-donate]) | [💚][🤝cb-issues] | [💚][🤝cb-pulls] | ➖ | ⭕️ No Matrix |
| 🐙 [Dynamoid/dynamoid on GitHub][📜src-gh] | Another Mirror | [💚][🤝gh-issues] | [💚][🤝gh-pulls] | [💚][📜gh-wiki] | 💯 Full Matrix |

</details>

### Enterprise Support [![Tidelift](https://tidelift.com/badges/package/rubygems/dynamoid)](https://tidelift.com/subscription/pkg/rubygems-dynamoid?utm_source=rubygems-dynamoid&utm_medium=referral&utm_campaign=readme)

Available as part of the Tidelift Subscription.

<details markdown="1">
 <summary>Need enterprise-level guarantees?</summary>

The maintainers of this and thousands of other packages are working with Tidelift to deliver commercial support and maintenance for the open source packages you use to build your applications. Save time, reduce risk, and improve code health, while paying the maintainers of the exact packages you use.

[![Get help from me on Tidelift][🏙️entsup-tidelift-img]][🏙️entsup-tidelift]

- 💡Subscribe for support guarantees covering _all_ your FLOSS dependencies
- 💡Tidelift is part of [Sonar][🏙️entsup-tidelift-sonar]
- 💡Tidelift pays maintainers to maintain the software you depend on!<br/>📊`@`Pointy Haired Boss: An [enterprise support][🏙️entsup-tidelift] subscription is "[never gonna let you down][🧮kloc]", and *supports* open source maintainers

Alternatively:

- [![Ruby Users Forum][✉️ruby-forum-img]][✉️ruby-forum]
- [![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite]
- [![Get help from me on Upwork][👨🏼‍🏫expsup-upwork-img]][👨🏼‍🏫expsup-upwork]
- [![Get help from me on Codementor][👨🏼‍🏫expsup-codementor-img]][👨🏼‍🏫expsup-codementor]

</details>

## ✨ Installation

Install the gem and add to the application's Gemfile by executing:

```console
bundle add dynamoid
```

If bundler is not being used to manage dependencies, install the gem by executing:

```console
gem install dynamoid
```

## ⚙️ Configuration

Minimal connection settings are required. Configure Dynamoid in a Rails
initializer or directly in your application setup:

```ruby
require "dynamoid"

Dynamoid.configure do |config|
  config.access_key = "REPLACE_WITH_ACCESS_KEY_ID"
  config.secret_key = "REPLACE_WITH_SECRET_ACCESS_KEY"
  config.region = "REPLACE_WITH_REGION" # e.g. "us-west-2"
end
```

## 🔧 Basic Usage

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

## 🦷 FLOSS Funding

While Dynamoid tools are free software and will always be, the project would benefit immensely from some funding.
Raising a monthly budget of... "dollars" would make the project more sustainable.

We welcome both individual and corporate sponsors! We also offer a
wide array of funding channels to account for your preferences.
Currently, [Open Collective][🖇osc] is our preferred funding platform.

**If you're working in a company that's making significant use of Dynamoid tools we'd
appreciate it if you suggest to your company to become a Dynamoid sponsor.**

You can support the development of Dynamoid tools via
[GitHub Sponsors][🖇sponsor],
[Liberapay][⛳liberapay],
[PayPal][🖇paypal],
[Open Collective][🖇osc]
and [Tidelift][🏙️entsup-tidelift].

| 📍 NOTE |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| If doing a sponsorship in the form of donation is problematic for your company <br/> from an accounting standpoint, we'd recommend the use of Tidelift, <br/> where you can get a support-like subscription instead. |

### Open Collective for Individuals

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/dynamoid#backer)]

NOTE: [kettle-readme-backers][kettle-readme-backers] updates this list every day, automatically.

<!-- OPENCOLLECTIVE-INDIVIDUALS:START -->
No backers yet. Be the first!
<!-- OPENCOLLECTIVE-INDIVIDUALS:END -->

### Open Collective for Organizations

Become a sponsor and get your logo on our README on GitHub with a link to your site. [[Become a sponsor](https://opencollective.com/dynamoid#sponsor)]

NOTE: [kettle-readme-backers][kettle-readme-backers] updates this list every day, automatically.

<!-- OPENCOLLECTIVE-ORGANIZATIONS:START -->
No sponsors yet. Be the first!
<!-- OPENCOLLECTIVE-ORGANIZATIONS:END -->

[kettle-readme-backers]: https://github.com/Dynamoid/dynamoid/blob/main/bin/kettle-readme-backers

### Another way to support open-source

I’m driven by a passion to foster a thriving open-source community – a space where people can tackle complex problems, no matter how small. Revitalizing libraries that have fallen into disrepair, and building new libraries focused on solving real-world challenges, are my passions. I was recently affected by layoffs, and the tech jobs market is unwelcoming. I’m reaching out here because your support would significantly aid my efforts to provide for my family, and my farm (11 🐔 chickens, 2 🐶 dogs, 3 🐰 rabbits, 8 🐈‍ cats).

If you work at a company that uses my work, please encourage them to support me as a corporate sponsor. My work on gems you use might show up in `bundle fund`.

I’m developing a new library, [floss_funding][🖇floss-funding-gem], designed to empower open-source developers like myself to get paid for the work we do, in a sustainable way. Please give it a look.

**[Floss-Funding.dev][🖇floss-funding.dev]: 👉️ No network calls. 👉️ No tracking. 👉️ No oversight. 👉️ Minimal crypto hashing. 💡 Easily disabled nags**

[![OpenCollective Backers][🖇osc-backers-i]][🖇osc-backers] [![OpenCollective Sponsors][🖇osc-sponsors-i]][🖇osc-sponsors] [![Sponsor Me on Github][🖇sponsor-img]][🖇sponsor] [![Liberapay Goal Progress][⛳liberapay-img]][⛳liberapay] [![Donate on PayPal][🖇paypal-img]][🖇paypal] [![Buy me a coffee][🖇buyme-small-img]][🖇buyme] [![Donate to my FLOSS efforts at ko-fi.com][🖇kofi-img]][🖇kofi]

## 🔐 Security

See [SECURITY.md][🔐security].

## 🤝 Contributing

If you need some ideas of where to help, you could work on adding more code coverage,
or if it is already 💯 (see [below](#code-coverage)) check [issues][🤝gh-issues] or [PRs][🤝gh-pulls],
or use the gem and think about how it could be better.

We [![Keep A Changelog][📗keep-changelog-img]][📗keep-changelog] so if you make changes, remember to update it.

See [CONTRIBUTING.md][🤝contributing] for more detailed instructions.

### 🚀 Release Instructions

See [CONTRIBUTING.md][🤝contributing].

### Code Coverage

<details markdown="1">
<summary>Coverage service badges</summary>

[![Coverage Graph][🏀codecov-g]][🏀codecov]

[![Coveralls Test Coverage][🏀coveralls-img]][🏀coveralls]

[![QLTY Test Coverage][🏀qlty-covi]][🏀qlty-cov]

</details>

### 🪇 Code of Conduct

Everyone interacting with this project's codebases, issue trackers,
chat rooms and mailing lists agrees to follow the [![Contributor Covenant 2.1][🪇conduct-img]][🪇conduct].

## 🌈 Contributors

[![Contributors][🖐contributors-img]][🖐contributors]

Made with [contributors-img][🖐contrib-rocks].

Also see GitLab Contributors: [https://gitlab.com/Dynamoid/dynamoid/-/graphs/main][🚎contributors-gl]

<details markdown="1">
 <summary>⭐️ Star History</summary>

<a href="https://star-history.com/Dynamoid/dynamoid&Date">
 <picture>
 <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Dynamoid/dynamoid&type=Date&theme=dark" />
 <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Dynamoid/dynamoid&type=Date" />
 <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Dynamoid/dynamoid&type=Date" />
 </picture>
</a>

</details>

## 📌 Versioning

This library follows [![Semantic Versioning 2.0.0][📌semver-img]][📌semver] for its public API where practical.
For most applications, prefer the [Pessimistic Version Constraint][📌pvc] with two digits of precision.

For example:

```ruby
spec.add_dependency("dynamoid", "~> 3.0")
```

<details markdown="1">
<summary>📌 Is "Platform Support" part of the public API? More details inside.</summary>

Dropping support for a platform can be a breaking change for affected users.
If a release changes supported platforms, it should be called out clearly in the changelog and versioned with that impact in mind.

To get a better understanding of how SemVer is intended to work over a project's lifetime,
read this article from the creator of SemVer:

- ["Major Version Numbers are Not Sacred"][📌major-versions-not-sacred]

</details>

See [CHANGELOG.md][📌changelog] for a list of releases.

## 📄 License

The gem is available as open source under the terms of
the [MIT](https://github.com/Dynamoid/dynamoid/blob/main/MIT.md) [![License: MIT][📄license-img]][📄license-ref].

### © Copyright

See [LICENSE.md][📄license] for the official copyright notice.

<details markdown="1">
<summary>Copyright holders</summary>

- Copyright (c) 2012 Anantha Kumaran
- Copyright (c) 2012 Andrés Rojas
- Copyright (c) 2012 bcoe
- Copyright (c) 2012 Craig Heneveld
- Copyright (c) 2012 Jason Dew
- Copyright (c) 2012 Jon Spalding
- Copyright (c) 2012 Josh Symonds
- Copyright (c) 2012 Kishorekumar Neelamegam
- Copyright (c) 2012-2013 Logan Bowers
- Copyright (c) 2013 Alexander Lang
- Copyright (c) 2013 Daniel Marschner
- Copyright (c) 2013 Lane LaRue
- Copyright (c) 2013 Luis Arias
- Copyright (c) 2013 Michael Patricios
- Copyright (c) 2013 Stefan
- Copyright (c) 2014, 2018, 2022-2023 bonty
- Copyright (c) 2015 peeyush1234
- Copyright (c) 2015 Philip White
- Copyright (c) 2015-2016 Sumanth Ravipati
- Copyright (c) 2015 Wan
- Copyright (c) 2016 Agustin Cavilliotti
- Copyright (c) 2016 Alex Cabrera
- Copyright (c) 2016 Alex Emelyanov
- Copyright (c) 2016 Alex Nisnevich
- Copyright (c) 2016 Amir Manji
- Copyright (c) 2016 Brenden Kokoszka
- Copyright (c) 2016 Everett Wetchler
- Copyright (c) 2016 Gas unknown developer
- Copyright (c) 2016 NielsKSchjoedt
- Copyright (c) 2016 Nigel Brookes-Thomas
- Copyright (c) 2016 Pascal Corpet
- Copyright (c) 2016-2018, 2022, 2025-2026 Peter Boling
- Copyright (c) 2016, 2018-2019 Richard Hsu
- Copyright (c) 2016 Sergey Petrenko
- Copyright (c) 2016 Tadas Tamosauskas
- Copyright (c) 2016 Yuichiro Someya
- Copyright (c) 2017-2026 Andrew Konchin
- Copyright (c) 2017 Richard Hsu
- Copyright (c) 2018 Alex Ghiculescu
- Copyright (c) 2018 baloran
- Copyright (c) 2018 Danilo Cabello
- Copyright (c) 2018 kokuyouwind
- Copyright (c) 2018 Kristijan Novoselic
- Copyright (c) 2018 Kristijan Novoselic
- Copyright (c) 2018 lulu-ulul
- Copyright (c) 2018 Micael Nussbaumer
- Copyright (c) 2019 Ash Tyndall
- Copyright (c) 2019-2020 Brian Malinconico
- Copyright (c) 2019 Emma Hyde
- Copyright (c) 2019 Emma Hyde
- Copyright (c) 2019 Postmodern
- Copyright (c) 2019 ryosuke_sato
- Copyright (c) 2019 Tejas Mandke
- Copyright (c) 2020 Aaron Allen
- Copyright (c) 2020 Alex Gascón
- Copyright (c) 2020 Ankun Yu
- Copyright (c) 2020 Benjamin Vetter
- Copyright (c) 2020 Dima
- Copyright (c) 2020 Jānis Kiršteins
- Copyright (c) 2020 Michael Miller
- Copyright (c) 2020 Nigel Gomes
- Copyright (c) 2020 Remo Mueller
- Copyright (c) 2020  TheSmartnik
- Copyright (c) 2021-2022 a5-stable
- Copyright (c) 2021 Brian Malinconico
- Copyright (c) 2021 Jan Bajena
- Copyright (c) 2021 Konstantin Kanyuka
- Copyright (c) 2022 Hiroki Koike
- Copyright (c) 2022 rahul342
- Copyright (c) 2022 ta1kt0me
- Copyright (c) 2022 Tony Spataro
- Copyright (c) 2022 Tony Spataro
- Copyright (c) 2023 kiharito
- Copyright (c) 2023 Maximilian Babescu
- Copyright (c) 2024-2025 Chris Hobbs
- Copyright (c) 2024 Dalibor Nasevic
- Copyright (c) 2024 ndjndj
- Copyright (c) 2025 Aaron Alberg
- Copyright (c) 2025 Chris Hobbs
- Copyright (c) 2025 ogidow

</details>

## 🤑 A request for help

Maintainers have teeth and need to pay their dentists.
After getting laid off in an RIF in March, and encountering difficulty finding a new one,
I began spending most of my time building open source tools.
I'm hoping to be able to pay for my kids' health insurance this month,
so if you value the work I am doing, I need your support.
Please consider sponsoring me or the project.

To join the community or get help, use the RubyForum or Discord.

[![Ruby Users Forum][✉️ruby-forum-img]][✉️ruby-forum]
[![Live Chat on Discord][✉️discord-invite-img-ftb]][✉️discord-invite]

To say "thanks!" ☝️ Join the community or 👇️ send money.

[![Sponsor dynamoid/dynamoid on Open Source Collective][🖇osc-all-bottom-img]][🖇osc] 💌 [![Sponsor me on GitHub Sponsors][🖇sponsor-bottom-img]][🖇sponsor] 💌 [![Sponsor me on Liberapay][⛳liberapay-bottom-img]][⛳liberapay] 💌 [![Donate on PayPal][🖇paypal-bottom-img]][🖇paypal]

### Please give the project a star ⭐ ♥.

Many parts of this project are actively managed by a [kettle-jem](https://github.com/structuredmerge/structuredmerge-ruby/tree/main/gems/kettle-jem) smart template utilizing [StructuredMerge.org](https://structuredmerge.org) merge contracts.

Thanks for RTFM. ☺️

[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg?logo=liberapay&color=a51611&style=flat
[⛳liberapay-bottom-img]: https://img.shields.io/liberapay/goal/pboling.svg?style=for-the-badge&logo=liberapay&color=a51611
[⛳liberapay]: https://liberapay.com/pboling/donate
[🖇osc-all-img]: https://img.shields.io/opencollective/all/dynamoid
[🖇osc-sponsors-img]: https://img.shields.io/opencollective/sponsors/dynamoid
[🖇osc-backers-img]: https://img.shields.io/opencollective/backers/dynamoid
[🖇osc-backers]: https://opencollective.com/dynamoid#backer
[🖇osc-backers-i]: https://opencollective.com/dynamoid/backers/badge.svg?style=flat
[🖇osc-sponsors]: https://opencollective.com/dynamoid#sponsor
[🖇osc-sponsors-i]: https://opencollective.com/dynamoid/sponsors/badge.svg?style=flat
[🖇osc-all-bottom-img]: https://img.shields.io/opencollective/all/dynamoid?style=for-the-badge
[🖇osc-sponsors-bottom-img]: https://img.shields.io/opencollective/sponsors/dynamoid?style=for-the-badge
[🖇osc-backers-bottom-img]: https://img.shields.io/opencollective/backers/dynamoid?style=for-the-badge
[🖇osc]: https://opencollective.com/dynamoid
[🖇sponsor-img]: https://img.shields.io/badge/Sponsor_Me!-pboling.svg?style=social&logo=github
[🖇sponsor-bottom-img]: https://img.shields.io/badge/Sponsor_Me!-pboling-blue?style=for-the-badge&logo=github
[🖇sponsor]: https://github.com/sponsors/pboling
[🖇kofi-img]: https://img.shields.io/badge/ko--fi-%E2%9C%93-a51611.svg?style=flat
[🖇kofi]: https://ko-fi.com/pboling
[🖇buyme-small-img]: https://img.shields.io/badge/buy_me_a_coffee-%E2%9C%93-a51611.svg?style=flat
[🖇buyme-img]: https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20latte&emoji=&slug=pboling&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff
[🖇buyme]: https://www.buymeacoffee.com/pboling
[🖇paypal-img]: https://img.shields.io/badge/donate-paypal-a51611.svg?style=flat&logo=paypal
[🖇paypal-bottom-img]: https://img.shields.io/badge/donate-paypal-a51611.svg?style=for-the-badge&logo=paypal&color=0A0A0A
[🖇paypal]: https://www.paypal.com/paypalme/peterboling
[🖇floss-funding.dev]: https://floss-funding.dev
[🖇floss-funding-gem]: https://github.com/galtzo-floss/floss_funding
[✉️discord-invite]: https://discord.gg/3qme4XHNKN
[✉️discord-invite-img-ftb]: https://img.shields.io/discord/1373797679469170758?style=for-the-badge&logo=discord
[✉️ruby-friends-img]: https://img.shields.io/badge/daily.dev-%F0%9F%92%8E_Ruby_Friends-0A0A0A?style=for-the-badge&logo=dailydotdev&logoColor=white
[✉️ruby-friends]: https://app.daily.dev/squads/rubyfriends
[✉️ruby-forum-top-img]: https://img.shields.io/discourse/topics?server=https%3A%2F%2Fwww.rubyforum.org&style=flat&logo=discourse&label=Ruby%20Users%20Forum
[✉️ruby-forum-img]: https://img.shields.io/discourse/topics?server=https%3A%2F%2Fwww.rubyforum.org&style=for-the-badge&logo=discourse&label=Ruby%20Users%20Forum
[✉️ruby-forum]: https://www.rubyforum.org/tag/dynamoid

[✇bundle-group-pattern]: https://gist.github.com/pboling/4564780
[⛳️gem-namespace]: https://github.com/Dynamoid/dynamoid
[⛳️namespace-img]: https://img.shields.io/badge/namespace-Dynamoid-3C2D2D.svg?style=square&logo=ruby&logoColor=white
[⛳️gem-name]: https://clickgems.clickhouse.com/dashboard/dynamoid
[⛳️name-img]: https://img.shields.io/badge/name-dynamoid-3C2D2D.svg?style=square&logo=rubygems&logoColor=red
[⛳️tag-img]: https://img.shields.io/github/tag/Dynamoid/dynamoid.svg
[⛳️tag]: https://github.com/Dynamoid/dynamoid/releases
[🚂maint-blog]: http://www.railsbling.com/tags/dynamoid
[🚂maint-blog-img]: https://img.shields.io/badge/blog-railsbling-0093D0.svg?style=for-the-badge&logo=rubyonrails&logoColor=orange
[🚂maint-contact]: http://www.railsbling.com/contact
[🚂maint-contact-img]: https://img.shields.io/badge/Contact-Maintainer-0093D0.svg?style=flat&logo=rubyonrails&logoColor=red
[💖🖇linkedin]: http://www.linkedin.com/in/peterboling
[💖🖇linkedin-img]: https://img.shields.io/badge/LinkedIn-Profile-0B66C2?style=flat&logo=newjapanprowrestling
[💖✌️wellfound]: https://wellfound.com/u/peter-boling
[💖✌️wellfound-img]: https://img.shields.io/badge/peter--boling-orange?style=flat&logo=wellfound
[💖💲crunchbase]: https://www.crunchbase.com/person/peter-boling
[💖💲crunchbase-img]: https://img.shields.io/badge/peter--boling-purple?style=flat&logo=crunchbase
[💖🐘ruby-mast]: https://ruby.social/@galtzo
[💖🐘ruby-mast-img]: https://img.shields.io/mastodon/follow/109447111526622197?domain=https://ruby.social&style=flat&logo=mastodon&label=Ruby%20@galtzo
[💖🦋bluesky]: https://bsky.app/profile/galtzo.com
[💖🦋bluesky-img]: https://img.shields.io/badge/@galtzo.com-0285FF?style=flat&logo=bluesky&logoColor=white
[💖🌳linktree]: https://linktr.ee/galtzo
[💖🌳linktree-img]: https://img.shields.io/badge/galtzo-purple?style=flat&logo=linktree
[💖💁🏼‍♂️devto]: https://dev.to/galtzo
[💖💁🏼‍♂️devto-img]: https://img.shields.io/badge/dev.to-0A0A0A?style=flat&logo=devdotto&logoColor=white
[💖💁🏼‍♂️aboutme]: https://about.me/peter.boling
[💖💁🏼‍♂️aboutme-img]: https://img.shields.io/badge/about.me-0A0A0A?style=flat&logo=aboutme&logoColor=white
[💖🧊berg]: https://codeberg.org/pboling
[💖🐙hub]: https://github.org/pboling
[💖🛖hut]: https://sr.ht/~galtzo/
[💖🧪lab]: https://gitlab.com/pboling
[👨🏼‍🏫expsup-upwork]: https://www.upwork.com/freelancers/~014942e9b056abdf86?mp_source=share
[👨🏼‍🏫expsup-upwork-img]: https://img.shields.io/badge/UpWork-13544E?style=for-the-badge&logo=Upwork&logoColor=white
[👨🏼‍🏫expsup-codementor]: https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github
[👨🏼‍🏫expsup-codementor-img]: https://img.shields.io/badge/CodeMentor-Get_Help-1abc9c?style=for-the-badge&logo=CodeMentor&logoColor=white
[🏙️entsup-tidelift]: https://tidelift.com/subscription/pkg/rubygems-dynamoid?utm_source=rubygems-dynamoid&utm_medium=referral&utm_campaign=readme
[🏙️entsup-tidelift-img]: https://img.shields.io/badge/Tidelift_and_Sonar-Enterprise_Support-FD3456?style=for-the-badge&logo=sonar&logoColor=white
[🏙️entsup-tidelift-sonar]: https://blog.tidelift.com/tidelift-joins-sonar
[💁🏼‍♂️peterboling]: http://www.peterboling.com
[🚂railsbling]: http://www.railsbling.com
[📜src-gl-img]: https://img.shields.io/badge/GitLab-FBA326?style=for-the-badge&logo=Gitlab&logoColor=orange
[📜src-gl]: https://gitlab.com/Dynamoid/dynamoid
[📜src-cb-img]: https://img.shields.io/badge/CodeBerg-4893CC?style=for-the-badge&logo=CodeBerg&logoColor=blue
[📜src-cb]: https://codeberg.org/Dynamoid/dynamoid
[📜src-gh-img]: https://img.shields.io/badge/GitHub-238636?style=for-the-badge&logo=GitHub&logoColor=green
[📜src-gh]: https://github.com/Dynamoid/dynamoid
[📜docs-cr-rd-img]: https://img.shields.io/badge/RubyDoc-Current_Release-943CD2?style=for-the-badge&logo=readthedocs&logoColor=white
[📜docs-head-rd-img]: https://img.shields.io/badge/YARD_on_Galtzo.com-HEAD-943CD2?style=for-the-badge&logo=readthedocs&logoColor=white
[📜gl-wiki]: https://gitlab.com/Dynamoid/dynamoid/-/wikis/home
[📜gh-wiki]: https://github.com/Dynamoid/dynamoid/wiki
[📜gl-wiki-img]: https://img.shields.io/badge/wiki-gitlab-943CD2.svg?style=for-the-badge&logo=gitlab&logoColor=white
[📜gh-wiki-img]: https://img.shields.io/badge/wiki-github-943CD2.svg?style=for-the-badge&logo=github&logoColor=white
[👽dl-rank]: https://clickgems.clickhouse.com/dashboard/dynamoid
[👽dl-ranki]: https://img.shields.io/gem/dt/dynamoid.svg
[👽version]: https://clickgems.clickhouse.com/dashboard/dynamoid
[👽versioni]: https://img.shields.io/gem/v/dynamoid.svg
[🏀qlty-mnt]: https://qlty.sh/gh/Dynamoid/projects/dynamoid
[🏀qlty-mnti]: https://qlty.sh/gh/Dynamoid/projects/dynamoid/maintainability.svg
[🏀qlty-cov]: https://qlty.sh/gh/Dynamoid/projects/dynamoid/metrics/code?sort=coverageRating
[🏀qlty-covi]: https://qlty.sh/gh/Dynamoid/projects/dynamoid/coverage.svg
[🏀codecov]: https://codecov.io/gh/Dynamoid/dynamoid
[🏀codecovi]: https://codecov.io/gh/Dynamoid/dynamoid/graph/badge.svg
[🏀coveralls]: https://coveralls.io/github/Dynamoid/dynamoid?branch=main
[🏀coveralls-img]: https://coveralls.io/repos/github/Dynamoid/dynamoid/badge.svg?branch=main
[🚎ruby-2.4-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-2.4.yml
[🚎ruby-2.5-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-2.5.yml
[🚎ruby-2.6-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-2.6.yml
[🚎ruby-2.7-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-2.7.yml
[🚎ruby-3.0-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-3.0.yml
[🚎ruby-3.1-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-3.1.yml
[🚎ruby-3.2-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-3.2.yml
[🚎ruby-3.3-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-3.3.yml
[🚎ruby-3.4-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/ruby-3.4.yml
[🚎jruby-9.2-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby-9.2.yml
[🚎jruby-9.3-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby-9.3.yml
[🚎jruby-9.4-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby-9.4.yml
[🚎jruby-10.0-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby-10.0.yml
[🚎truby-22.3-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-22.3.yml
[🚎truby-23.0-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-23.0.yml
[🚎truby-23.1-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-23.1.yml
[🚎truby-24.2-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-24.2.yml
[🚎truby-25.0-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-25.0.yml
[🚎truby-33.0-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffleruby-33.0.yml
[🚎2-cov-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/coverage.yml
[🚎2-cov-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/coverage.yml/badge.svg
[🚎3-hd-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/heads.yml
[🚎3-hd-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/heads.yml/badge.svg
[🚎5-st-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/style.yml
[🚎5-st-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/style.yml/badge.svg
[🚎9-t-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffle.yml
[🚎9-t-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/truffle.yml/badge.svg
[🚎10-j-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby.yml
[🚎10-j-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/jruby.yml/badge.svg
[🚎11-c-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/current.yml
[🚎11-c-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/current.yml/badge.svg
[🚎12-crh-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/dep-heads.yml
[🚎12-crh-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/dep-heads.yml/badge.svg
[🚎13-🔒️-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/locked_deps.yml
[🚎13-🔒️-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/locked_deps.yml/badge.svg
[🚎14-🔓️-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/unlocked_deps.yml
[🚎14-🔓️-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/unlocked_deps.yml/badge.svg
[🚎15-🪪-wf]: https://github.com/Dynamoid/dynamoid/actions/workflows/license-eye.yml
[🚎15-🪪-wfi]: https://github.com/Dynamoid/dynamoid/actions/workflows/license-eye.yml/badge.svg
[💎ruby-2.3i]: https://img.shields.io/badge/Ruby-2.3_(%F0%9F%9A%ABCI)-AABBCC?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.4i]: https://img.shields.io/badge/Ruby-2.4-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.5i]: https://img.shields.io/badge/Ruby-2.5-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.6i]: https://img.shields.io/badge/Ruby-2.6-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-2.7i]: https://img.shields.io/badge/Ruby-2.7-DF00CA?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.0i]: https://img.shields.io/badge/Ruby-3.0-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.1i]: https://img.shields.io/badge/Ruby-3.1-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.2i]: https://img.shields.io/badge/Ruby-3.2-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.3i]: https://img.shields.io/badge/Ruby-3.3-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-3.4i]: https://img.shields.io/badge/Ruby-3.4-CC342D?style=for-the-badge&logo=ruby&logoColor=white
[💎ruby-c-i]: https://img.shields.io/badge/Ruby-current-CC342D?style=for-the-badge&logo=ruby&logoColor=green
[💎ruby-headi]: https://img.shields.io/badge/Ruby-HEAD-CC342D?style=for-the-badge&logo=ruby&logoColor=blue
[💎truby-22.3i]: https://img.shields.io/badge/Truffle_Ruby-22.3-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-23.0i]: https://img.shields.io/badge/Truffle_Ruby-23.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-23.1i]: https://img.shields.io/badge/Truffle_Ruby-23.1-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-24.2i]: https://img.shields.io/badge/Truffle_Ruby-24.2-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-25.0i]: https://img.shields.io/badge/Truffle_Ruby-25.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-33.0i]: https://img.shields.io/badge/Truffle_Ruby-33.0-34BCB1?style=for-the-badge&logo=ruby&logoColor=pink
[💎truby-c-i]: https://img.shields.io/badge/Truffle_Ruby-current-34BCB1?style=for-the-badge&logo=ruby&logoColor=green
[💎truby-headi]: https://img.shields.io/badge/Truffle_Ruby-HEAD-34BCB1?style=for-the-badge&logo=ruby&logoColor=blue
[💎jruby-9.2i]: https://img.shields.io/badge/JRuby-9.2-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-9.3i]: https://img.shields.io/badge/JRuby-9.3-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-9.4i]: https://img.shields.io/badge/JRuby-9.4-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-10.0i]: https://img.shields.io/badge/JRuby-10.0-FBE742?style=for-the-badge&logo=ruby&logoColor=red
[💎jruby-c-i]: https://img.shields.io/badge/JRuby-current-FBE742?style=for-the-badge&logo=ruby&logoColor=green
[💎jruby-headi]: https://img.shields.io/badge/JRuby-HEAD-FBE742?style=for-the-badge&logo=ruby&logoColor=blue
[🤝gh-issues]: https://github.com/Dynamoid/dynamoid/issues
[🤝gh-pulls]: https://github.com/Dynamoid/dynamoid/pulls
[🤝gl-issues]: https://gitlab.com/Dynamoid/dynamoid/-/issues
[🤝gl-pulls]: https://gitlab.com/Dynamoid/dynamoid/-/merge_requests
[🤝cb-issues]: https://codeberg.org/Dynamoid/dynamoid/issues
[🤝cb-pulls]: https://codeberg.org/Dynamoid/dynamoid/pulls
[🤝cb-donate]: https://donate.codeberg.org/
[🤝contributing]: https://github.com/Dynamoid/dynamoid/blob/main/CONTRIBUTING.md
[🏀codecov-g]: https://codecov.io/gh/Dynamoid/dynamoid/graph/badge.svg
[🖐contrib-rocks]: https://contrib.rocks
[🖐contributors]: https://github.com/Dynamoid/dynamoid/graphs/contributors
[🖐contributors-img]: https://contrib.rocks/image?repo=Dynamoid/dynamoid
[🚎contributors-gl]: https://gitlab.com/Dynamoid/dynamoid/-/graphs/main
[🪇conduct]: https://github.com/Dynamoid/dynamoid/blob/main/CODE_OF_CONDUCT.md
[🪇conduct-img]: https://img.shields.io/badge/Contributor_Covenant-2.1-259D6C.svg
[📌pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-259D6C.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📌changelog]: https://github.com/Dynamoid/dynamoid/blob/main/CHANGELOG.md
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-34495e.svg?style=flat
[📌gitmoji]: https://gitmoji.dev
[📌gitmoji-img]: https://img.shields.io/badge/gitmoji_commits-%20%F0%9F%98%9C%20%F0%9F%98%8D-34495e.svg?style=flat-square
[🧮kloc]: https://www.youtube.com/watch?v=dQw4w9WgXcQ
[🧮kloc-img]: https://img.shields.io/badge/KLOC-5.053-FFDD67.svg?style=for-the-badge&logo=YouTube&logoColor=blue
[🔐security]: https://github.com/Dynamoid/dynamoid/blob/main/SECURITY.md
[🔐security-img]: https://img.shields.io/badge/security-policy-259D6C.svg?style=flat
[📄copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year
[📄license]: LICENSE.md
[📄license-ref]: https://github.com/Dynamoid/dynamoid/blob/main/MIT.md
[📄license-img]: https://img.shields.io/badge/License-MIT-259D6C.svg
[📄license-compat]: https://www.apache.org/legal/resolved.html#category-a
[📄license-compat-img]: https://img.shields.io/badge/Apache_Compatible:_Category_A-%E2%9C%93-259D6C.svg?style=flat&logo=Apache

[📄ilo-declaration]: https://www.ilo.org/declaration/lang--en/index.htm
[📄ilo-declaration-img]: https://img.shields.io/badge/ILO_Fundamental_Principles-✓-259D6C.svg?style=flat
[🚎yard-current]: http://rubydoc.info/gems/dynamoid
[🚎yard-head]: https://dynamoid.galtzo.com
[💎stone_checksums]: https://github.com/galtzo-floss/stone_checksums
[💎SHA_checksums]: https://gitlab.com/Dynamoid/dynamoid/-/tree/main/checksums
[💎rlts]: https://github.com/rubocop-lts/rubocop-lts
[💎rlts-img]: https://img.shields.io/badge/code_style_&_linting-rubocop--lts-34495e.svg?plastic&logo=ruby&logoColor=white
[💎appraisal2]: https://github.com/appraisal-rb/appraisal2
[💎appraisal2-img]: https://img.shields.io/badge/appraised_by-appraisal2-34495e.svg?plastic&logo=ruby&logoColor=white
[💎d-in-dvcs]: https://railsbling.com/posts/dvcs/put_the_d_in_dvcs/

<!-- kettle-jem:metadata:start -->
| Field | Value |
|---|---|
| Package | dynamoid |
| Description | 💎 Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement. |
| Homepage | https://github.com/Dynamoid/dynamoid |
| Source | https://github.com/Dynamoid/dynamoid |
| License | `MIT` |
| Funding | https://github.com/sponsors/Dynamoid, https://github.com/sponsors/pboling, https://opencollective.com/dynamoid, https://thanks.dev/u/gh/pboling, https://tidelift.com/funding/github/rubygems/dynamoid, https://www.buymeacoffee.com/pboling |
<!-- kettle-jem:metadata:end -->
