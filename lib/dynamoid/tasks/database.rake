require 'dynamoid'
require 'dynamoid/tasks/database'

namespace :dynamoid do
  desc "Foobar"
  task :setup do
    Dynamoid::Tasks::Database.create_tables
  end

  desc 'TOTO'
  task :ping do
    success = ::Dynamoid::Tasks::Database.ping
    msg = "Connection to DynamoDB #{success ? 'OK' : 'FAILED'}"
    msg << if Dynamoid.config.endpoint
             " at local endpoint: #{Dynamoid.config.endpoint}"
           else
             ' at remote AWS endpoint'
           end
    puts msg
  end
end
