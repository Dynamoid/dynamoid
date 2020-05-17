# frozen_string_literal: true

module Dynamoid
  # @private
  module DynamodbTimeZone
    def self.in_time_zone(value)
      case Dynamoid::Config.dynamodb_timezone
      when :utc
        value.utc.to_datetime
      when :local
        value.getlocal.to_datetime
      else
        value.in_time_zone(Dynamoid::Config.dynamodb_timezone).to_datetime
      end
    end
  end
end
