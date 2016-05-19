# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "dynamoid"
  s.version = "1.1.0"

  # Keep in sync with README
  s.authors = [
    'Josh Symonds',
    'Logan Bowers',
    'Craig Heneveld',
    'Anatha Kumaran',
    'Jason Dew',
    'Luis Arias',
    'Stefan Neculai',
    'Philip White',
    'Peeyush Kumar',
  ]
  s.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.markdown"
  ]
  # file list is generated with `git ls-files | grep -v -E -e '^spec/' -e '^\.' -e 'bin/'`
  s.files = %w(
    CHANGELOG.md
    Gemfile
    LICENSE.txt
    README.markdown
    Rakefile
    dynamoid.gemspec
    lib/dynamoid.rb
    lib/dynamoid/adapter.rb
    lib/dynamoid/adapter_plugin/aws_sdk_v2.rb
    lib/dynamoid/associations.rb
    lib/dynamoid/associations/association.rb
    lib/dynamoid/associations/belongs_to.rb
    lib/dynamoid/associations/has_and_belongs_to_many.rb
    lib/dynamoid/associations/has_many.rb
    lib/dynamoid/associations/has_one.rb
    lib/dynamoid/associations/many_association.rb
    lib/dynamoid/associations/single_association.rb
    lib/dynamoid/components.rb
    lib/dynamoid/config.rb
    lib/dynamoid/config/options.rb
    lib/dynamoid/criteria.rb
    lib/dynamoid/criteria/chain.rb
    lib/dynamoid/dirty.rb
    lib/dynamoid/document.rb
    lib/dynamoid/errors.rb
    lib/dynamoid/fields.rb
    lib/dynamoid/finders.rb
    lib/dynamoid/identity_map.rb
    lib/dynamoid/middleware/identity_map.rb
    lib/dynamoid/indexes.rb
    lib/dynamoid/persistence.rb
    lib/dynamoid/validations.rb
    lib/dynamoid/tasks/database.rb
  )
  s.homepage = "http://github.com/Dynamoid/Dynamoid"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Dynamoid is an ORM for Amazon's DynamoDB"

  s.add_runtime_dependency(%q<activemodel>, ["~> 4"])
  s.add_runtime_dependency(%q<aws-sdk-resources>, ["~> 2"])
  s.add_runtime_dependency(%q<concurrent-ruby>, [">= 1.0"])
  s.add_development_dependency(%q<rake>, [">= 0"])
  s.add_development_dependency(%q<rspec>, ["~> 3"])
  s.add_development_dependency(%q<bundler>, [">= 0"])
  s.add_development_dependency(%q<yard>, [">= 0"])
  s.add_development_dependency(%q<github-markup>, [">= 0"])
  s.add_development_dependency(%q<pry>, [">= 0"])
  s.add_development_dependency(%q<coveralls>, [">= 0"])
end
