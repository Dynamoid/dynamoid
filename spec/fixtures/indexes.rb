# frozen_string_literal: true

module IndexesSpecs
  class CustomType
    def dynamoid_dump
      name
    end

    def self.dynamoid_load(string)
      new(string.to_s)
    end
  end
end
