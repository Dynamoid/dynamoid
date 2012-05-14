# encoding: utf-8
module Dynamoid
  
  # All the error specific to Dynamoid.
  module Errors
    
    # Generic error class.
    class Error < StandardError; end
    
    # InvalidField is raised when an attribute is specified for an index, but the attribute does not exist.
    class InvalidField < Error; end
    
    # MissingRangeKey is raised when a table that requires a range key is quieried without one.
    class MissingRangeKey < Error; end

    # DocumentNotValid is raised when the document fails validation.
    class DocumentNotValid < Error
      def initialize(document)
        super("Validation failed: #{document.errors.full_messages.join(", ")}")
      end
    end

    class InvalidQuery < Error; end
  end
end
