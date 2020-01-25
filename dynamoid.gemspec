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
  spec.email = ['peter.boling@gmail.com', 'brian@stellaservice.com', 'andry.konchin@gmail.com']

  spec.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  spec.summary = "Dynamoid is an ORM for Amazon's DynamoDB"
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features|.dev|Vagrantfile)/}) }
  spec.homepage = 'http://github.com/Dynamoid/Dynamoid'
  spec.licenses = ['MIT']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activemodel', '>=4'
  spec.add_runtime_dependency 'aws-sdk-dynamodb', '~> 1'
  spec.add_runtime_dependency 'concurrent-ruby', '>= 1.0'
  spec.add_runtime_dependency 'null-logger'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'wwtd'
  spec.add_development_dependency 'yard'
end
