# frozen_string_literal: true

require_relative 'action'

module Dynamoid
  class TransactionWrite
    class Upsert < UpdateUpsert
      # Upsert is just like Update buts skips the existence check so a new record can be created when it's missing.
      # No callbacks.
      def initialize(model_or_model_class, attributes, options = {})
        options = options.reverse_merge(skip_existence_check: true)
        super(model_or_model_class, attributes, options)
        raise Dynamoid::Errors::MissingHashKey unless hash_key.present?
        raise Dynamoid::Errors::MissingRangeKey unless !model_class.range_key? || range_key.present?
      end

      # no callbacks are run

      # only run validations if a model has been provided
      def valid?
        model ? model.valid? : true
      end
    end
  end
end
