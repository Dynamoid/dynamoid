# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

desc "Start DynamoDBLocal, run tests, clean up"
task :unattended_spec do |t|

  if system('bin/start_dynamodblocal')
    puts 'DynamoDBLocal started; proceeding with specs.'
  else
    raise 'Unable to start DynamoDBLocal.  Cannot run unattended specs.'
  end

  #Cleanup
  at_exit do
    unless system('bin/stop_dynamodblocal')
      $stderr.puts 'Unable to cleanly stop DynamoDBLocal.'
    end
  end

  Rake::Task["spec"].invoke
end

require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb', "README", "LICENSE"]   # optional
  t.options = ['-m', 'markdown'] # optional
end

desc 'Publish documentation to gh-pages'
task :publish do
  Rake::Task['yard'].invoke
  `git add .`
  `git commit -m 'Regenerated documentation'`
  `git checkout gh-pages`
  `git clean -fdx`
  `git checkout master -- doc`
  `cp -R doc/* .`
  `git rm -rf doc/`
  `git add .`
  `git commit -m 'Regenerated documentation'`
  `git pull`
  `git push`
  `git checkout master`
end

task :default => :spec
