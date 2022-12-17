# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Dynamoid.adapter.clear_cache!
  end
end
