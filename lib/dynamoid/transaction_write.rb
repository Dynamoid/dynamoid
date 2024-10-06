# frozen_string_literal: true

require 'dynamoid/transaction_write/action'
require 'dynamoid/transaction_write/create'
require 'dynamoid/transaction_write/delete'
require 'dynamoid/transaction_write/destroy'
require 'dynamoid/transaction_write/update'
require 'dynamoid/transaction_write/upsert'

module Dynamoid
  class TransactionWrite
    attr_accessor :action_inputs, :models

    def initialize(_options = {})
      @action_inputs = []
      @models = []
    end

    def self.execute(options = {})
      transaction = new(options)
      yield(transaction)
      transaction.commit
    end

    def commit
      return unless @action_inputs.present? # nothing to commit

      Dynamoid.adapter.transact_write_items(@action_inputs)
      models.each { |model| model.new_record = false }
    end

    def save!(model, options = {})
      save(model, options.reverse_merge(raise_validation_error: true))
    end

    def save(model, options = {})
      model.new_record? ? create(model, {}, options) : update(model, {}, options)
    end

    def create!(model_or_model_class, attributes = {}, options = {}, &block)
      create(model_or_model_class, attributes, options.reverse_merge(raise_validation_error: true), &block)
    end

    def create(model_or_model_class, attributes = {}, options = {}, &block)
      add_action_and_validate Dynamoid::TransactionWrite::Create.new(model_or_model_class, attributes, options, &block)
    end

    # upsert! does not exist because upserting instances that can raise validation errors is not officially supported

    def upsert(model_or_model_class, attributes = {}, options = {}, &block)
      add_action_and_validate Dynamoid::TransactionWrite::Upsert.new(model_or_model_class, attributes, options, &block)
    end

    def update!(model_or_model_class, attributes = {}, options = {}, &block)
      update(model_or_model_class, attributes, options.reverse_merge(raise_validation_error: true), &block)
    end

    def update(model_or_model_class, attributes = {}, options = {}, &block)
      add_action_and_validate Dynamoid::TransactionWrite::Update.new(model_or_model_class, attributes, options, &block)
    end

    def delete(model_or_model_class, key_or_attributes = {}, options = {})
      add_action_and_validate Dynamoid::TransactionWrite::Delete.new(model_or_model_class, key_or_attributes, options)
    end

    def destroy!(model_or_model_class, key_or_attributes = {}, options = {})
      destroy(model_or_model_class, key_or_attributes, options.reverse_merge(raise_validation_error: true))
    end

    def destroy(model_or_model_class, key_or_attributes = {}, options = {})
      add_action_and_validate Dynamoid::TransactionWrite::Destroy.new(model_or_model_class, key_or_attributes, options)
    end

    private

    # validates unless validations are skipped
    # runs callbacks unless callbacks are skipped
    # raise validation error or returns false if not valid
    # otherwise adds hash of action to list in preparation for committing
    def add_action_and_validate(action)
      if !action.skip_validation? && !action.valid?
        raise Dynamoid::Errors::DocumentNotValid, action.model if action.raise_validation_error?

        return false
      end

      action.run_callbacks do
        @action_inputs << action.to_h
      end

      action.changes_applied # action has been processed and added to queue so mark as applied
      models << action.model if action.model

      action.model || true # return model if it exists
    end
  end
end
