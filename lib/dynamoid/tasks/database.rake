require 'dynamoid'
require 'dynamoid/tasks/database'

namespace :dynamoid do
  desc "Creates DynamoDB tables, one for each of your Dynamoid models - does not modify pre-existing tables"
  task :create_tables do
    tables = Dynamoid::Tasks::Database.create_tables
    result = tables[:created].map( |c| "#{c} created") + tables[:existing].map( |e| "#{e} not modified")
    result.sort.each{ |r| puts r }
  end

  desc 'Tests if the DynamoDB instance can be contacted using your configuration'
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
