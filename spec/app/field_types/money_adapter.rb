# frozen_string_literal: true

require_relative 'money_base'

class Money < MoneyBase
end

class MoneyAdapter
  def self.dynamoid_dump(money_obj)
    money_obj.value.to_s
  end

  def self.dynamoid_load(money_str)
    Money.new(BigDecimal(money_str)) unless money_str.nil?
  end
end
