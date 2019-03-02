# frozen_string_literal: true

require 'coveralls'
require 'active_support/testing/time_helpers.rb'

Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'dynamoid'
require 'pry'
require 'byebug' if ENV['DEBUG']

require 'dynamodb_local'

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
end

Dynamoid.logger.level = Logger::FATAL

MODELS = File.join(File.dirname(__FILE__), 'app/models')

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

Dir[File.join(MODELS, '*.rb')].sort.each { |file| require file }

RSpec.configure do |config|
  config.order = :random
  config.raise_errors_for_deprecations!
  config.alias_it_should_behave_like_to :configured_with, 'configured with'

  config.include NewClassHelper
  config.include DumpingHelper
  config.include PersistenceHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:each) do
    DynamoDBLocal.delete_all_specified_tables!
    Dynamoid.adapter.clear_cache!
  end

  config.around(:each) do |example|
    included_models_before = Dynamoid.included_models.dup
    example.run
    Dynamoid.included_models.replace(included_models_before)
  end
end
