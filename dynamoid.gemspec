# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dynamoid/version'

Gem::Specification.new do |spec|
  spec.name = 'dynamoid'
  spec.version = Dynamoid::VERSION

  # Keep in sync with README
  spec.authors = [
    'Josh Symonds',
    'Logan Bowers',
    'Craig Heneveld',
    'Anatha Kumaran',
    'Jason Dew',
    'Luis Arias',
    'Stefan Neculai',
    'Philip White',
    'Peeyush Kumar',
    'Sumanth Ravipati',
    'Pascal Corpet',
    'Brian Glusman',
    'Peter Boling',
    'Andrew Konchin'
  ]
  spec.email = ['andry.konchin@gmail.com', 'peter.boling@gmail.com', 'brian@stellaservice.com']

  spec.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  spec.summary = "Dynamoid is an ORM for Amazon's DynamoDB"
  spec.files = Dir[
    'CHANGELOG.md',
    'README.md',
    'LICENSE.txt',
    'lib/**/*',
    'SECURITY.md'
  ]
  spec.homepage = 'http://github.com/Dynamoid/dynamoid'
  spec.licenses = ['MIT']
  spec.require_paths = ['lib']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "https://github.com/Dynamoid/dynamoid/tree/v#{spec.version}"
  spec.metadata['changelog_uri'] = "https://github.com/Dynamoid/dynamoid/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = 'https://github.com/Dynamoid/dynamoid/issues'
  spec.metadata['documentation_uri'] = "https://www.rubydoc.info/gems/dynamoid/#{spec.version}"
  spec.metadata['wiki_uri'] = 'https://github.com/Dynamoid/dynamoid/wiki'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_runtime_dependency 'activemodel', '>=4'
  spec.add_runtime_dependency 'aws-sdk-dynamodb', '~> 1.0'
  spec.add_runtime_dependency 'concurrent-ruby', '>= 1.0'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'overcommit'
  # Since 0.13.0 pry is incompatible with old versions of pry-byebug.
  # We use these old versions of pry-byebug to run tests on Ruby 2.3 which new versions don't support
  spec.add_development_dependency 'pry', '~> 0.12.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  # 'rubocop-lts' is for Ruby 2.3+, see https://rubocop-lts.gitlab.io/
  spec.add_development_dependency 'rubocop-lts', '~> 10.0'
  spec.add_development_dependency 'rubocop-md'
  spec.add_development_dependency 'rubocop-packaging'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'yard'
end
