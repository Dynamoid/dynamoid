# frozen_string_literal: true

require 'dynamoid/transaction_write/create'
require 'dynamoid/transaction_write/delete_with_primary_key'
require 'dynamoid/transaction_write/delete_with_instance'
require 'dynamoid/transaction_write/destroy'
require 'dynamoid/transaction_write/save'
require 'dynamoid/transaction_write/update_fields'
require 'dynamoid/transaction_write/update_attributes'
require 'dynamoid/transaction_write/upsert'

module Dynamoid
  class TransactionWrite
    attr_reader :actions

    def self.execute
      transaction = self.new
      yield transaction
      transaction.commit
    end

    def initialize
      @actions = []
    end

    def commit
      action_requests = @actions.reject(&:aborted?).map(&:action_request)
      return if action_requests.empty?

      Dynamoid.adapter.transact_write_items(action_requests)
      @actions.reject(&:aborted?).each(&:on_completing)

      nil
    end

    def save!(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_validation_error: true)
      register_action action
    end

    def save(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_validation_error: false)
      register_action action
    end

    def create!(model_class, attributes = {})
      action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_validation_error: true)
      register_action action
    end

    def create(model_class, attributes = {})
      action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_validation_error: false)
      register_action action
    end

    # upsert! does not exist because upserting instances that can raise validation errors is not officially supported

    def upsert(model_class, attributes, options = {})
      action = Dynamoid::TransactionWrite::Upsert.new(model_class, attributes, **options)
      register_action action
    end

    def update_fields(model_class, hash_key, range_key = nil, attributes)
      action = Dynamoid::TransactionWrite::UpdateFields.new(model_class, hash_key, range_key, attributes)
      register_action action
    end

    def update_attributes(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_validation_error: false)
      register_action action
    end

    def update_attributes!(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_validation_error: true)
      register_action action
    end

    def delete(model_or_model_class, primary_key = nil)
      if model_or_model_class.is_a? Class
        action = Dynamoid::TransactionWrite::DeleteWithPrimaryKey.new(model_or_model_class, primary_key)
        register_action action
      else
        action = Dynamoid::TransactionWrite::DeleteWithInstance.new(model_or_model_class)
        register_action action
      end
    end

    def destroy!(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model)
      register_action action
    end

    def destroy(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model)
      register_action action
    end

    private

    def register_action(action)
      @actions << action
      action.on_registration
      action.observable_by_user_result
    end
  end
end
