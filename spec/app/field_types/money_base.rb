# frozen_string_literal: true

class MoneyBase
  attr_reader :value

  def initialize(value)
    raise 'Money can be initialized only with BigDecimal!' unless value.is_a?(BigDecimal)
    @value = value
  end

  def ==(other)
    other.is_a?(MoneyBase) && @value == other.value
  end

  def to_s
    format('$%.2f', @value.to_s('F'))
  end
end
