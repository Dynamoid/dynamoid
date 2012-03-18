# encoding: utf-8
module Dynamoid
  module Errors
    class Error < StandardError; end

    class InvalidField < Error; end
    class MissingRangeKey < Error; end

    class DocumentNotValid < Error
      def initialize(document)
        super("Validation failed: #{document.errors.full_messages.join(", ")}")
      end
    end
  end
end
