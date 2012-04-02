$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

MODELS = File.join(File.dirname(__FILE__), "app/models")

require 'rspec'
require 'dynamoid'
require 'mocha'

Dynamoid.configure do |config|
  if ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
    config.adapter = 'aws_sdk'
    config.access_key = ENV['ACCESS_KEY']
    config.secret_key = ENV['SECRET_KEY']
  else
    config.adapter = 'local'
  end
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
  
  if ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
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
  else
    config.before(:each) do
      Dynamoid::Adapter.reset_data
    end
  end
end
