# frozen_string_literal: true

# NOTE: This Gemfile is only relevant to local development.
#       It allows during local development:
#         - code coverage reports to be generated
#         - style linting to be run with RuboCop & extensions
#       All CI builds use files in gemfiles/*.
source 'https://rubygems.org'

# Specify your gem's dependencies in dynamoid.gemspec
gemspec

# Only add to the set of gems from the gemspec when running on local.
# All CI jobs must use a discrete Gemfile located at gemfiles/*.gemfile. They will not use this Gemfile
if ENV['CI'].nil?
  ruby_version = Gem::Version.new(RUBY_VERSION)
  minimum_version = ->(version, engine = 'ruby') { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == engine }
  committing = minimum_version.call('2.4')
  linting = minimum_version.call('2.7')
  coverage = minimum_version.call('2.7')

  platforms :mri do
    if committing
      gem 'overcommit'
    end
    if linting
      gem 'rubocop-md', require: false
      gem 'rubocop-packaging', require: false
      gem 'rubocop-performance', require: false
      gem 'rubocop-rake', require: false
      gem 'rubocop-rspec', require: false
      gem 'rubocop-thread_safety', require: false
    end
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

  gem 'activemodel', '= 7.0.4'

  # There is an issue with Rails 7.1 fixed in 3.12.5.
  # See:
  # - https://github.com/rspec/rspec-mocks/pull/1534
  # - https://github.com/rspec/rspec-mocks/issues/1530
  gem 'rspec-mocks', '>= 3.12.5'
end
