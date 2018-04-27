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
      "Peter Boling",
      "Andrew Konchin"
  ]
  spec.email = ["peter.boling@gmail.com", "brian@stellaservice.com"]

  spec.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  spec.summary = "Dynamoid is an ORM for Amazon's DynamoDB"
  spec.extra_rdoc_files = [
      "LICENSE.txt",
      "README.md"
  ]
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features|.dev|Vagrantfile)/}) }
  spec.homepage = "http://github.com/Dynamoid/Dynamoid"
  spec.licenses = ["MIT"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # This form of switching the gem dependencies is not compatible with wwtd & appraisal
  # if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.2.2")
  #   spec.add_runtime_dependency(%q<activemodel>, [">= 4", "< 5.1.0"])
  #   spec.add_development_dependency(%q<activesupport>, [">= 4", "< 5.1.0"])
  # else
  #   spec.add_runtime_dependency(%q<activemodel>, ["~> 4"])
  #   spec.add_development_dependency(%q<activesupport>, ["~> 4"])
  # end
  spec.add_runtime_dependency(%q<activemodel>, [">= 4", "<= 5.1"])
  spec.add_development_dependency(%q<activesupport>, [">= 4", "<= 5.1"])
  spec.add_runtime_dependency(%q<aws-sdk-resources>, ["~> 2"])
  spec.add_runtime_dependency(%q<concurrent-ruby>, [">= 1.0"])
  spec.add_development_dependency "pry"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "appraisal", "~> 2.1"
  spec.add_development_dependency "wwtd", "~> 1.3"
  spec.add_development_dependency(%q<yard>, [">= 0"])
  spec.add_development_dependency "coveralls", "~> 0.8"
end
