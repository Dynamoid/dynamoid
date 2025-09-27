# frozen_string_literal: true

# Clean up top level constants introduced in a test (e.g. class names).
RSpec.configure do |config|
  config.before :each, :remove_constants do |example|
    example.metadata[:remove_constants].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name) # rubocop:disable RSpec/RemoveConst
    end
  end

  config.after :each, :remove_constants do |example|
    example.metadata[:remove_constants].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name) # rubocop:disable RSpec/RemoveConst
    end
  end
end
