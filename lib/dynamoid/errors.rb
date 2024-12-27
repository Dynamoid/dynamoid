# frozen_string_literal: true

module Dynamoid
  # All the errors specific to Dynamoid.  The goal is to mimic ActiveRecord.
  module Errors
    # Generic Dynamoid error
    class Error < StandardError; end

    class MissingHashKey < Error; end
    class MissingRangeKey < Error; end

    class MissingIndex < Error; end

    # InvalidIndex is raised when an invalid index is specified, for example if
    # specified key attribute(s) or projected attributes do not exist.
    class InvalidIndex < Error
      def initialize(item)
        if item.is_a? String
          super
        else
          super("Validation failed: #{item.errors.full_messages.join(', ')}")
        end
      end
    end

    class RecordNotSaved < Error
      attr_reader :record

      def initialize(record)
        super('Failed to save the item')
        @record = record
      end
    end

    class RecordNotDestroyed < Error
      attr_reader :record

      def initialize(record)
        super('Failed to destroy the item')
        @record = record
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

    class RecordNotFound < Error
    end

    class DocumentNotValid < Error
      attr_reader :document

      def initialize(document)
        super("Validation failed: #{document.errors.full_messages.join(', ')}")
        @document = document
      end
    end

    class InvalidQuery < Error; end

    class UnsupportedKeyType < Error; end

    class UnknownAttribute < Error; end

    class SubclassNotFound < Error; end

    class Rollback < Error; end
  end
end
