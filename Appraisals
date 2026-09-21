# frozen_string_literal: true

appraise 'rails-4-2' do
  gem 'activemodel', '~> 4.2.0'

  # Add bigdecimal gem to support Ruby 2.7 and above:
  # https://github.com/rails/rails/issues/34822

  # Compatibility with Ruby versions:
  # https://github.com/ruby/bigdecimal#which-version-should-you-select
  #
  # Actually bigdecimal 1.4.x works on all the Ruby versions till Ruby 3.0
  gem 'bigdecimal', '~> 1.4.0', platform: :mri

  # ActiveSupport 4.2 is incompatible with json 2.19+ (due to infinite recursion in
  # alias_method_chain :to_json) and json 3.0+ (removed quirks_mode option).
  # Constrain to < 2.4.0 to use the compatible 2.3.x series shipped with Ruby 2.7.
  gem 'json', '< 2.4.0'
end

appraise 'rails-5-0' do
  gem 'activemodel', '~> 5.0.0'

  # ActiveSupport 5.0 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-5-1' do
  gem 'activemodel', '~> 5.1.0'

  # ActiveSupport 5.1 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-5-2' do
  gem 'activemodel', '~> 5.2.0'

  # ActiveSupport 5.2 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-6-0' do
  gem 'activemodel', '~> 6.0.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # Since Ruby 4.0 benchmark becomes a bundled gem and should be added into gemspec/Gemfile files
  gem 'benchmark'

  # ActiveSupport 6.0 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-6-1' do
  gem 'activemodel', '~> 6.1.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # Since Ruby 4.0 benchmark becomes a bundled gem and should be added into gemspec/Gemfile files
  gem 'benchmark'

  # ActiveSupport 6.1 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-7-0' do
  gem 'activemodel', '~> 7.0.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # ActiveSupport 7.0 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-7-1' do
  gem 'activemodel', '~> 7.1.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # ActiveSupport 7.1 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-7-2' do
  gem 'activemodel', '~> 7.2.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # ActiveSupport 7.2 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-8-0' do
  gem 'activemodel', '~> 8.0.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'

  # ActiveSupport 8.0 is incompatible with json 3.0+ (passes removed quirks_mode option)
  gem 'json', '< 3.0.0'
end

appraise 'rails-8-1' do
  gem 'activemodel', '~> 8.1.0'

  # Since Ruby 3.4 these dependencies are bundled gems so should be specified explicitly.
  gem 'mutex_m'
  gem 'base64'
  gem 'bigdecimal'
end
