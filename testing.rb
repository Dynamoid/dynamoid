$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

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

MODELS = File.join(File.dirname(__FILE__), "spec/app/models")

Dir[ File.join(MODELS, "*.rb") ].sort.each { |file| require file }


