# frozen_string_literal: true

# To get coverage
# On Local, default (HTML) output coverage is turned on with Ruby 2.6+:
#   bundle exec rspec spec
# On Local, all output formats with Ruby 2.6+:
#   COVER_ALL=true bundle exec rspec spec
#
# On CI, all output formats, the ENV variables CI is always set,
#   and COVER_ALL, and CI_CODECOV, are set in the coverage.yml workflow only,
#   so coverage only runs in that workflow, and outputs all formats.
#

SimpleCov.configure do
  if SimpleCov::Configuration.method_defined?(:cover)
    cover "lib/**/*.rb", "lib/**/*.rake", "exe/*.rb"
  else
    track_files "{lib/**/*.rb,lib/**/*.rake,exe/*.rb}"
  end
  enable_coverage :branch
  primary_coverage :branch
  add_filter "spec"
  # Why exclude version.rb? See: https://github.com/simplecov-ruby/simplecov/issues/557#issuecomment-410105995
  add_filter "lib/dynamoid/version.rb"
  track_files "**/*.rb"
end
