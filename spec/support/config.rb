# frozen_string_literal: true

# Set given config options and roll them back after a test complision
RSpec.configure do |config|
  config.around :each, :config do |example|
    config = example.metadata[:config]
    config_old = {}

    config.each do |key, value|
      config_old[key] = Dynamoid::Config.send(key)
      Dynamoid::Config.send(:"#{key}=", value)
    end

    example.run

    config.each_key do |key|
      Dynamoid::Config.send(:"#{key}=", config_old[key])
    end
  end
end
