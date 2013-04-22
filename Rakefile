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

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "dynamoid"
  gem.homepage = "http://github.com/Veraticus/Dynamoid"
  gem.license = "MIT"
  gem.summary = "Dynamoid is an ORM for Amazon's DynamoDB"
  gem.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  gem.email = "josh@joshsymonds.com"
  gem.authors = ["Josh Symonds"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

desc "Start fake_dynamo, run tests, cleanup" 
task :unattended_spec do |t|
  require 'tmpdir'
  require 'socket'

  dir = Dir.mktmpdir
  data_file = File.join(dir, "data.fdb")

  #Launch fake_dynamo
  pid = Process.spawn'fake_dynamo', '-d', data_file, err: '/dev/null', out: '/dev/null'
  #Cleanup
  at_exit {
    Process.kill('TERM', pid)
    FileUtils.rmtree(dir)
  }
  
  #Wait for fake_dynamo to start taking requests
  40.downto(0) do |count| #Wait up to 2 seconds
    begin
      s = TCPSocket.new 'localhost', 4567
      s.close
      break
    rescue Errno::ECONNREFUSED
      raise if(count == 0)
      sleep 0.1
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
