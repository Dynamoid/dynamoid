# frozen_string_literal: true

module Dynamoid
  # @private
  module ApplicationTimeZone
    def self.at(value)
      case Dynamoid::Config.application_timezone
      when :utc
        ActiveSupport::TimeZone['UTC'].at(value).to_datetime
      when :local
        Time.at(value).to_datetime
      when String
        ActiveSupport::TimeZone[Dynamoid::Config.application_timezone].at(value).to_datetime
      end
    end

    def self.utc_offset
      case Dynamoid::Config.application_timezone
      when :utc
        0
      when :local
        Time.now.utc_offset
      when String
        ActiveSupport::TimeZone[Dynamoid::Config.application_timezone].now.utc_offset
      end
    end
  end
end
