require_relative 'money_base'

class MoneyClassDump < MoneyBase
  def self.dynamoid_load(str)
    if !str.nil?
      self.new(BigDecimal.new(str))
    end
  end

  def self.dynamoid_dump(v)
    if v.is_a?(self.class)
      v.v.to_s
    else
      BigDecimal.new(v.to_s).to_s
    end
  end

  def self.load(str)
    raise 'This should not have been called.'
  end

  def dump
    raise 'This should not have been called.'
  end
end
