# frozen_string_literal: true

class Wrapper
  class Wrapped
    attr_accessor :foo, :bar

    def initialize(foo: nil, bar: nil)
      @foo = foo
      @bar = bar
    end

    def to_h
      {
        foo: @foo,
        bar: @bar,
      }
    end

    class << self
      def from_h(h)
        Wrapped.new(**h.symbolize_keys)
      end
    end
  end

  class WrapperAdapter
    class << self
      def dynamoid_dump(obj)
        obj.to_h
      end

      def dynamoid_load(hash)
        Wrapped.from_h(hash)
      end
    end
  end

  include Dynamoid::Document

  field :wrapped, WrapperAdapter

  delegate_missing_to :wrapped
end
