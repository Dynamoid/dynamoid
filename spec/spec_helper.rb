$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

MODELS = File.join(File.dirname(__FILE__), "app/models")

require 'rspec'
require 'dynamoid'
require 'pry'
require 'mocha'
require 'aws-sdk'

ENV['ACCESS_KEY'] ||= 'abcd'
ENV['SECRET_KEY'] ||= '1234'

Aws.config.update({
          region: 'us-west-2',
          credentials: Aws::Credentials.new(ENV['ACCESS_KEY'], ENV['SECRET_KEY'])
          })

Dynamoid.configure do |config|
  config.endpoint = 'http://localhost:4567'
  config.adapter = 'aws_sdk_v2'
  config.namespace = 'dynamoid_tests'
  config.warn_on_scan = false
end

Dynamoid.logger.level = Logger::FATAL

MODELS = File.join(File.dirname(__FILE__), "app/models")

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Dir[ File.join(MODELS, "*.rb") ].sort.each { |file| require file }

RSpec.configure do |config|
  config.alias_it_should_behave_like_to :configured_with, "configured with"
  config.mock_with(:mocha)

  config.before(:each) do
    Dynamoid::Adapter.list_tables.each do |table|
      if table =~ /^#{Dynamoid::Config.namespace}/
        
        Dynamoid::Adapter.truncate(table)
        # table = Dynamoid::Adapter.get_table(table)
        # table.items.each {|i| i.delete}
      end
    end
  end

  config.after(:suite) do
    Dynamoid::Adapter.list_tables.each do |table|
      Dynamoid::Adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
    end
  end
end
