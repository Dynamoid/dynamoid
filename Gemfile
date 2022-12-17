# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in dynamoid.gemspec
gemspec

ruby_version = Gem::Version.new(RUBY_VERSION)
minimum_version = ->(version, engine = 'ruby') { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == engine }
coverage = minimum_version.call('2.7')

platforms :mri do
  if coverage
    gem 'codecov', '~> 0.6' # For CodeCov
    gem 'simplecov', '~> 0.21', require: false
    gem 'simplecov-cobertura' # XML for Jenkins
    gem 'simplecov-json' # For CodeClimate
    gem 'simplecov-lcov', '~> 0.8', require: false
  end
end

platforms :jruby do
  # Add `binding.pry` to your code where you want to drop to REPL
  gem 'pry-debugger-jruby'
end

platforms :ruby do
  gem 'pry-byebug'
end
