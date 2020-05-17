# frozen_string_literal: true

if defined? Rails

  module Dynamoid
    # @private
    class Railtie < Rails::Railtie
      rake_tasks do
        Dir[File.join(File.dirname(__FILE__), 'tasks/*.rake')].each { |f| load f }
      end
    end
  end

end
