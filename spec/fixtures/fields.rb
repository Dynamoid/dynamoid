# frozen_string_literal: true

module FieldsSpecs
  class User
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def dynamoid_dump
      name
    end

    def eql?(other)
      name == other.name
    end

    def hash
      name.hash
    end

    def self.dynamoid_load(string)
      new(string.to_s)
    end
  end
end
