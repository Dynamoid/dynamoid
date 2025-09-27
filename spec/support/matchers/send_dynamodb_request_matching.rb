# frozen_string_literal: true

class SendRequestMatching < RSpec::Matchers::BuiltIn::BaseMatcher
  # @api private
  def matches?(event_proc)
    PrintHttpBody.enabled = true
    PrintHttpBody.logged_requests.clear

    event_proc.call

    PrintHttpBody.enabled = false

    PrintHttpBody.logged_requests
      .select { |r| r[:operation_name] == @operation_name }
      .any? { |r| values_match?(@pattern, r[:body]) }
  end

  # @api private
  def does_not_match?(_event_proc)
    !matches?(given_proc, :negative_expectation) && given_proc.is_a?(Proc)
  end

  # @api private
  # @return [String]
  def failure_message
    "expected #{PrintHttpBody.logged_requests} to contain #{@operation_name} request matching #{@pattern}"
  end

  # @api private
  # @return [String]
  def failure_message_when_negated
    "expected #{PrintHttpBody.logged_requests} not to contain #{@operation_name} request matching #{@pattern}"
  end

  # @api private
  # @return [String]
  def description
    "match #{@operation_name} request #{@pattern}"
  end

  # @private
  def supports_block_expectations?
    true
  end

  # @private
  def supports_value_expectations?
    false
  end

  private

  def initialize(operation_name, pattern)
    super()
    @operation_name = operation_name.to_s
    @pattern = pattern.stringify_keys
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

def send_request_matching(operation, pattern)
  SendRequestMatching.new(operation, pattern)
end
