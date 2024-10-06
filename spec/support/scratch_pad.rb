# frozen_string_literal: true

# It's a way to have a side effect and to check it.
#
# There are two use scenarios for this class.
#
# Scenario #1:
#   ScratchPad.clear
#   ScratchPad.record(value)
#   ScratchPad.recorded # => value
#
# Scenario #2:
#   ScratchPad.record []
#   ScratchPad << val1
#   ScratchPad << val2
#   ScratchPad.recorded #> [val1, val2]
module ScratchPad
  def self.clear
    @record = []
  end

  def self.record(arg)
    @record = arg
  end

  def self.<<(arg)
    @record << arg
  end

  def self.recorded
    @record
  end

  def self.inspect
    "<ScratchPad @record=#{@record.inspect}>"
  end
end

