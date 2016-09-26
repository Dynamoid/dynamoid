# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dynamoid/version"

Gem::Specification.new do |spec|
  spec.name = "dynamoid"
  spec.version = Dynamoid::VERSION

  # Keep in sync with README
  spec.authors = [
      "Josh Symonds",
      "Logan Bowers",
      "Craig Heneveld",
      "Anatha Kumaran",
      "Jason Dew",
      "Luis Arias",
      "Stefan Neculai",
      "Philip White",
      "Peeyush Kumar",
      "Sumanth Ravipati",
      "Pascal Corpet",
      "Brian Glusman",
      "Peter Boling"
  ]
  spec.email = ["peter.boling@gmail.com", "brian@stellaservice.com"]

  spec.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  spec.summary = "Dynamoid is an ORM for Amazon's DynamoDB"
  spec.extra_rdoc_files = [
      "LICENSE.txt",
      "README.md"
  ]
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features)/}) }
  spec.homepage = "http://github.com/Dynamoid/Dynamoid"
  spec.licenses = ["MIT"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency(%q<activemodel>, [">= 4"])
  spec.add_runtime_dependency(%q<aws-sdk-resources>, ["~> 2"])
  spec.add_runtime_dependency(%q<concurrent-ruby>, [">= 1.0"])
  spec.add_development_dependency(%q<rake>, [">= 10"])
  spec.add_development_dependency(%q<bundler>, ["~> 1.12"])
  spec.add_development_dependency(%q<rspec>, [">= 3"])
  spec.add_development_dependency(%q<yard>, [">= 0"])
  spec.add_development_dependency(%q<github-markup>, [">= 0"])
  spec.add_development_dependency(%q<pry>, [">= 0"])
  spec.add_development_dependency(%q<coveralls>, [">= 0"])
  spec.add_development_dependency(%q<rspec-retry>, [">= 0"])
end
