# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each) do |example|
    included_models_before = Dynamoid.included_models.dup
    example.run
    Dynamoid.included_models.replace(included_models_before)
  end
end
