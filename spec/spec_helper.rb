# frozen_string_literal: true

# Standard Libs
# N/A

# Third Party Libs
# https://guides.rubyonrails.org/active_support_core_extensions.html#stand-alone-active-support
require 'active_support'
require 'active_support/testing/time_helpers'
require 'rspec'
require 'pry'

# Debugging
DEBUG = ENV['DEBUG'] == 'true'

ruby_version = Gem::Version.new(RUBY_VERSION)
minimum_version = ->(version, engine = 'ruby') { ruby_version >= Gem::Version.new(version) && RUBY_ENGINE == engine }
actual_version = lambda do |major, minor|
  actual = Gem::Version.new(ruby_version)
  major == actual.segments[0] && minor == actual.segments[1] && RUBY_ENGINE == 'ruby'
end
debugging = minimum_version.call('2.7') && DEBUG
RUN_COVERAGE = minimum_version.call('2.6') && (ENV['COVER_ALL'] || ENV['CI_CODECOV'] || ENV['CI'].nil?)
ALL_FORMATTERS = actual_version.call(2, 7) && (ENV['COVER_ALL'] || ENV['CI_CODECOV'] || ENV['CI'])

if DEBUG
  if debugging
    require 'byebug'
  elsif minimum_version.call('2.7', 'jruby')
    require 'pry-debugger-jruby'
  end
end

# Load Code Coverage as the last thing before this gem
if RUN_COVERAGE
  require 'simplecov' # Config file `.simplecov` is run immediately when simplecov loads
  require 'codecov'
  require 'simplecov-json'
  require 'simplecov-lcov'
  require 'simplecov-cobertura'
  if ALL_FORMATTERS
    # This would override the formatter set in .simplecov, if set
    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      c.single_report_path = 'coverage/lcov.info'
    end

    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter, # XML for Jenkins
      SimpleCov::Formatter::LcovFormatter,
      SimpleCov::Formatter::JSONFormatter, # For CodeClimate
      SimpleCov::Formatter::Codecov, # For CodeCov
    ]
  end
end

# This Gem
require 'dynamoid'
require 'dynamoid/log/formatter'

ENV['ACCESS_KEY'] ||= 'abcd'
ENV['SECRET_KEY'] ||= '1234'

Aws.config.update(
  region: 'us-west-2',
  credentials: Aws::Credentials.new(ENV['ACCESS_KEY'], ENV['SECRET_KEY'])
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
  config.order = :random
  config.raise_errors_for_deprecations!
  config.alias_it_should_behave_like_to :configured_with, 'configured with'

  config.include NewClassHelper
  config.include DumpingHelper
  config.include PersistenceHelper
  config.include ChainHelper
  config.include ActiveSupport::Testing::TimeHelpers
end
