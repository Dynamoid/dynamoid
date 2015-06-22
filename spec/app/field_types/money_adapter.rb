require_relative 'money_base'

class Money < MoneyBase
end

class MoneyAdapter
  def self.dynamoid_dump(money_obj)
    money_obj.v.to_s
  end

  def self.dynamoid_load(money_str)
    unless money_str.nil?
      Money.new(BigDecimal.new(money_str))
    end
  end
end
