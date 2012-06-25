$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

MODELS = File.join(File.dirname(__FILE__), "app/models")

require 'rspec'
require 'dynamoid'
require 'mocha'
require 'pry'

unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
  puts "Dynamoid needs ACCESS_KEY and SECRET_KEY to run the tests"
  exit 1
end

Dynamoid.configure do |config|
  config.adapter = 'aws_sdk'
  config.access_key = ENV['ACCESS_KEY']
  config.secret_key = ENV['SECRET_KEY']
  config.endpoint = 'localhost'
  config.use_ssl = false
  config.namespace = 'dynamoid_tests'
  config.warn_on_scan = false
end

Dynamoid.logger.level = Logger::FATAL

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Dir[ File.join(MODELS, "*.rb") ].sort.each { |file| require file }

RSpec.configure do |config|
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
