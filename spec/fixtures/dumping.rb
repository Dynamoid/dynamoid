# frozen_string_literal: true

module DumpingSpecs
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

  # implements both #dynamoid_dump and .dynamoid_dump methods
  class UserWithAdapterInterface
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def dynamoid_dump
      "#{name} (dumped with #dynamoid_dump)"
    end

    def self.dynamoid_dump(user)
      "#{user.name} (dumped with .dynamoid_dump)"
    end

    def self.dynamoid_load(string)
      new(string.to_s)
    end
  end

  # doesn't implement #dynamoid_dump/#dynamoid_load methods so requires an adapter
  class UserValue
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def eql?(other)
      name == other.name
    end

    def hash
      name.hash
    end
  end

  class UserValueAdapter
    def self.dynamoid_dump(user)
      user.name
    end

    def self.dynamoid_load(string)
      UserValue.new(string.to_s)
    end
  end

  class UserValueToArrayAdapter
    def self.dynamoid_dump(user)
      user.name.split
    end

    def self.dynamoid_load(array)
      array = array.name.split if array.is_a?(UserValue)
      UserValue.new(array.join(' '))
    end

    def self.dynamoid_field_type
      :array
    end
  end
end
