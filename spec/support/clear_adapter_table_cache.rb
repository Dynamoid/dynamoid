# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    Dynamoid.adapter.clear_cache!
  end
end
