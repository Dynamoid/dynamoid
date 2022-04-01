# frozen_string_literal: true

# Standard Libs
# N/A

# Engine Conditional Libs
if RUBY_ENGINE == 'jruby'
  # Workaround for JRuby CI failure https://github.com/jruby/jruby/issues/6547#issuecomment-774104996
  require 'i18n/backend'
  require 'i18n/backend/simple'
end

# Third Party Libs
require 'active_support/isolated_execution_state'
require 'active_support/testing/time_helpers'
require 'rspec'
require 'pry'
require 'byebug' if ENV['DEBUG']

# Load Code Coverage as the last thing before this gem
require 'coveralls'
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(File.dirname(__FILE__))

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
  config.endpoint = 'http://127.0.0.1:8000'
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
