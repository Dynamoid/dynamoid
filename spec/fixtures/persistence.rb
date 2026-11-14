# frozen_string_literal: true

module PersistenceSpec
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

    def self.dynamoid_load(string)
      new(string.to_s)
    end
  end

  class UserWithAge
    attr_accessor :age

    def initialize(age)
      self.age = age
    end

    def dynamoid_dump
      age
    end

    def eql?(other)
      age == other.age
    end

    def self.dynamoid_load(string)
      new(string.to_i)
    end

    def self.dynamoid_field_type
      :number
    end
  end

  module UserModuleAdapter
    def self.dynamoid_dump(user)
      user.name
    end

    def self.dynamoid_load(string)
      User.new(string.to_s)
    end
  end

  module UserWithAgeModuleAdapter
    def self.dynamoid_dump(user)
      user.age
    end

    def self.dynamoid_load(string)
      UserWithAge.new(string.to_i)
    end

    def self.dynamoid_field_type
      :number
    end
  end
end
