class MoneyBase
  attr_reader :v

  def initialize(v)
    raise 'Money can be initialized only with BigDecimal!' unless v.is_a?(BigDecimal)
    @v = v
  end

  def ==(other)
    other.is_a?(MoneyBase) && @v == other.v
  end

  def to_s
    '$%.2f' % @v.to_s('F')
  end
end
