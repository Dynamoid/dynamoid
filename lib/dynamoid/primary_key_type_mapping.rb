# frozen_string_literal: true

module Dynamoid
  class PrimaryKeyTypeMapping
    def self.dynamodb_type(type, options)
      case type
      when :string, :serialized
        :string
      when :integer, :number
        :number
      when :datetime
        string_format = if options[:store_as_string].nil?
                          Dynamoid::Config.store_datetime_as_string
                        else
                          options[:store_as_string]
                        end
        string_format ? :string : :number
      when :date
        string_format = if options[:store_as_string].nil?
                          Dynamoid::Config.store_date_as_string
                        else
                          options[:store_as_string]
                        end
        string_format ? :string : :number
      when Class
        type.respond_to?(:dynamoid_field_type) ? type.dynamoid_field_type : :string
      else
        raise 'unknown type'
      end
    end
  end
end
