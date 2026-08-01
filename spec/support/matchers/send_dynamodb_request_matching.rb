# frozen_string_literal: true

class SendRequestMatching < RSpec::Matchers::BuiltIn::BaseMatcher
  # @api private
  def matches?(event_proc)
    PrintHttpBody.enabled = true
    PrintHttpBody.logged_requests.clear

    event_proc.call

    PrintHttpBody.enabled = false

    matching_requests = PrintHttpBody.logged_requests
      .select { |r| r[:operation_name] == @operation_name }
      .select { |r| values_match?(@pattern, r[:body]) }

    @actual_count = matching_requests.size

    if @expected_count
      @actual_count == @expected_count
    else
      @actual_count > 0
    end
  end

  # @api private
  def does_not_match?(event_proc)
    !matches?(event_proc)
  end

  # @api private
  # @return [String]
  def failure_message
    if @expected_count
      "expected #{@operation_name} request matching #{@pattern} to be sent #{@expected_count} times, but it was sent #{@actual_count} times"
    else
      "expected #{@operation_name} request matching #{@pattern} to be sent, but it was not"
    end
  end

  # @api private
  # @return [String]
  def failure_message_when_negated
    if @expected_count
      "expected #{@operation_name} request matching #{@pattern} not to be sent #{@expected_count} times, but it was"
    else
      "expected #{@operation_name} request matching #{@pattern} not to be sent, but it was"
    end
  end

  # @api private
  # @return [String]
  def description
    if @expected_count
      "match #{@operation_name} request #{@pattern} exactly #{@expected_count} times"
    else
      "match #{@operation_name} request #{@pattern}"
    end
  end

  # @private
  def supports_block_expectations?
    true
  end

  # @private
  def supports_value_expectations?
    false
  end

  def exactly(count)
    @expected_count = count
    self
  end

  def times
    self
  end

  def once
    @expected_count = 1
    self
  end

  def twice
    @expected_count = 2
    self
  end

  private

  def initialize(operation_name, pattern)
    super()
    @operation_name = operation_name.to_s
    @pattern = pattern.stringify_keys
    @expected_count = nil
  end

  def values_match?(expected, actual)
    FuzzyMatcher.values_match?(expected, actual)
  end

  # https://github.com/rspec/rspec/blob/main/rspec-support/lib/rspec/support/fuzzy_matcher.rb
  module FuzzyMatcher
    # @api private
    def self.values_match?(expected, actual)
      if actual.is_a?(Hash)
        return hashes_match?(expected, actual) if expected.is_a?(Hash)
      elsif expected.is_a?(Array) && actual.is_a?(Enumerable) && !actual.is_a?(Struct)
        return arrays_match?(expected, actual.to_a)
      end

      return true if expected == actual

      begin
        expected === actual # rubocop:disable Style/CaseEquality
      rescue ArgumentError
        # Some objects, like 0-arg lambdas on 1.9+, raise
        # ArgumentError for `expected === actual`.
        false
      end
    end

    # @private
    def self.arrays_match?(expected_list, actual_list)
      return false if expected_list.size != actual_list.size

      expected_list.zip(actual_list).all? do |expected, actual|
        values_match?(expected, actual)
      end
    end

    # @private
    def self.hashes_match?(expected_hash, actual_hash)
      # The only difference between the original version - match Hash partially
      # return false if expected_hash.size != actual_hash.size

      expected_hash.all? do |expected_key, expected_value|
        actual_value = actual_hash.fetch(expected_key) { return false }
        values_match?(expected_value, actual_value)
      end
    end

    private_class_method :arrays_match?, :hashes_match?
  end
end

def send_request_matching(operation, pattern = {})
  SendRequestMatching.new(operation, pattern)
end
