# encoding: utf-8
module Dynamoid

  # All the errors specific to Dynamoid.  The goal is to mimic ActiveRecord.
  module Errors

    # Generic Dynamoid error
    class Error < StandardError; end

    class MissingRangeKey < Error; end

    class MissingIndex < Error; end

    # InvalidIndex is raised when an invalid index is specified, for example if
    # specified key attribute(s) or projected attributes do not exist.
    class InvalidIndex < Error
      def initialize(item)
        if (item.is_a? String)
          super(item)
        else
          super("Validation failed: #{item.errors.full_messages.join(", ")}")
        end
      end
    end

    # This class is intended to be private to Dynamoid.
    class ConditionalCheckFailedException < Error
      attr_reader :inner_exception

      def initialize(inner)
        super
        @inner_exception = inner
      end
    end

    class RecordNotUnique < ConditionalCheckFailedException
      attr_reader :original_exception

      def initialize(original_exception, record)
        super("Attempted to write record #{record} when its key already exists")
        @original_exception = original_exception
      end
    end

    class StaleObjectError < ConditionalCheckFailedException
      attr_reader :record, :attempted_action

      def initialize(record, attempted_action)
        super("Attempted to #{attempted_action} a stale object #{record}")
        @record = record
        @attempted_action = attempted_action
      end
    end

    class DocumentNotValid < Error
      attr_reader :document

      def initialize(document)
        super("Validation failed: #{document.errors.full_messages.join(", ")}")
        @document = document
      end
    end

    class InvalidQuery < Error; end
  end
end
