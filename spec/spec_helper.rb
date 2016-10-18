require "coveralls"
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift(File.dirname(__FILE__))

require "rspec"
require "rspec/retry"
require "dynamoid"
require "pry"
require "aws-sdk-resources"

require "dynamodb_local"

ENV["ACCESS_KEY"] ||= "abcd"
ENV["SECRET_KEY"] ||= "1234"

Aws.config.update({
          region: "us-west-2",
          credentials: Aws::Credentials.new(ENV["ACCESS_KEY"], ENV["SECRET_KEY"])
          })

Dynamoid.configure do |config|
  config.endpoint = "http://127.0.0.1:8000"
  config.namespace = "dynamoid_tests"
  config.warn_on_scan = false
  config.sync_retry_wait_seconds = 0
  config.sync_retry_max_times = 3
end

Dynamoid.logger.level = Logger::FATAL

MODELS = File.join(File.dirname(__FILE__), "app/models")

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Dir["#{File.dirname(__FILE__)}/app/field_types/*.rb"].each {|f| require f}

Dir[ File.join(MODELS, "*.rb") ].sort.each { |file| require file }

RSpec.configure do |config|
  config.order = :random
  config.raise_errors_for_deprecations!
  config.alias_it_should_behave_like_to :configured_with, "configured with"

  config.before(:each) do
    while !DynamoDBLocal.ensure_is_running!
      puts "Sleeping to allow DynamoDB to finish booting"
      sleep 1 # wait 5 seconds after restarting dynamodblocal
    end
    DynamoDBLocal.delete_all_specified_tables!
  end

  config.after(:each) do
    while !DynamoDBLocal.ensure_is_running!
      puts "Sleeping to allow DynamoDB to finish booting"
      sleep 1 # wait 5 seconds after restarting dynamodblocal
    end
    DynamoDBLocal.delete_all_specified_tables!
  end

  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on features
  config.around :each do |ex|
    ex.run_with_retry retry: 3
  end
end
