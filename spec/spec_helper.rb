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

AWS.config({
    :access_key_id => ENV['ACCESS_KEY'],
    :secret_access_key => ENV['SECRET_KEY'],
    :dynamo_db_endpoint => 'localhost',
    :dynamo_db_port => '4567',
    :use_ssl => false
})

Dynamoid.configure do |config|
  config.adapter = 'aws_sdk'
  config.namespace = 'dynamoid_tests'
  config.warn_on_scan = false
end

Dynamoid.logger.level = Logger::FATAL

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
        table = Dynamoid::Adapter.get_table(table)
        table.items.each {|i| i.delete}
      end
    end
  end

  config.after(:suite) do
    Dynamoid::Adapter.list_tables.each do |table|
      Dynamoid::Adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
    end
  end
end
