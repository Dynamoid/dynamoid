# frozen_string_literal: true

module DirtySpec
  class User
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def dynamoid_dump
      @name
    end

    def self.dynamoid_load(string)
      new(string.to_s)
    end
  end

  class UserWithEquality < User
    def eql?(other)
      if ScratchPad.recorded.is_a? Array
        ScratchPad << ['eql?', self, other]
      end

      @name == other.name
    end

    def ==(other)
      if ScratchPad.recorded.is_a? Array
        ScratchPad << ['==', self, other]
      end

      @name == other.name
    end

    def hash
      @name.hash
    end
  end
end
