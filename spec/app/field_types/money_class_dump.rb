# frozen_string_literal: true

require_relative 'money_base'

class MoneyClassDump < MoneyBase
  def self.dynamoid_load(str)
    new(BigDecimal(str)) unless str.nil?
  end

  def self.dynamoid_dump(obj)
    if obj.is_a?(self.class)
      obj.v.to_s
    else
      BigDecimal(obj.to_s).to_s
    end
  end

  def self.load(_str)
    raise 'This should not have been called.'
  end

  def dump
    raise 'This should not have been called.'
  end
end
