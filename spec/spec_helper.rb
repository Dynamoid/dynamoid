# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  raise error unless error.message.include?("kettle")
end

# Standard Libs

# Explicit requiring the "logger" library is needed for Rails 6.0-7.0
# See the following for details:
# - https://github.com/rails/rails/issues/54260
# - https://github.com/rails/rails/pull/49372
require 'logger'

# Third Party Libs
# https://guides.rubyonrails.org/active_support_core_extensions.html#stand-alone-active-support
require 'active_support'
require 'active_support/testing/time_helpers'
require 'rspec'
require 'pry'

# External RSpec & related config
require "kettle/test/rspec"
# `kettle/test/rspec` installs harness helpers documented in spec/README.md.

# Debugging
DEBUG = ENV['DEBUG'] == 'true'

ruby_version = Gem::Version.new(RUBY_VERSION)
minimum_version = ->(version, engine = 'ruby') { ruby_version >= Gem::Version.new(version) && engine == RUBY_ENGINE }
debugging = minimum_version.call('2.7') && DEBUG
RUN_COVERAGE = defined?(Kettle::Soup::Cover::DO_COV) && Kettle::Soup::Cover::DO_COV

if DEBUG
  if debugging
    require "debug" if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7")
  elsif minimum_version.call('2.7', 'jruby')
    require 'pry-debugger-jruby'
  end
end

# This Gem
require 'dynamoid'
require 'dynamoid/log/formatter'

ENV['ACCESS_KEY'] ||= 'abcd'
ENV['SECRET_KEY'] ||= '1234'

Aws.config.update(
  region: 'us-west-2',
  credentials: Aws::Credentials.new(ENV.fetch('ACCESS_KEY'), ENV.fetch('SECRET_KEY'))
)

Dynamoid.configure do |config|
  config.endpoint = 'http://localhost:8000'
  config.namespace = 'dynamoid_tests'
  config.warn_on_scan = false
  config.sync_retry_wait_seconds = 0
  config.sync_retry_max_times = 3
  config.log_formatter = Dynamoid::Log::Formatter::Debug.new
end

Dynamoid.logger.level = Logger::FATAL

MODELS = File.join(File.dirname(__FILE__), 'app/models')

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

Dir[File.join(MODELS, '*.rb')].sort.each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  config.raise_errors_for_deprecations!
  config.alias_it_should_behave_like_to :configured_with, 'configured with'

  config.include NewClassHelper
  config.include DumpingHelper
  config.include PersistenceHelper
  config.include ChainHelper
  config.include ActiveSupport::Testing::TimeHelpers
end
