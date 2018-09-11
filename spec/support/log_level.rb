RSpec.configure do |config|
  config.around :each, :log_level do |example|
    level_old = Dynamoid::Config.logger.level

    Dynamoid::Config.logger.level = example.metadata[:log_level]
    example.run
    Dynamoid::Config.logger.level = level_old
  end
end
