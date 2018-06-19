# frozen_string_literal: true

require_relative 'money_base'

class MoneyAsNumber < MoneyBase
  def self.dynamoid_load(str)
    new(BigDecimal(str)) unless str.nil?
  end

  def self.load(_str)
    raise 'This should not have been called.'
  end

  def self.dynamoid_field_type
    :number
  end

  def dynamoid_dump
    @value.to_f
  end

  def dump
    raise 'This should not have been called.'
  end
end
