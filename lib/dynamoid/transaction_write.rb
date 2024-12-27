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
      transaction = new

      begin
        yield transaction
      rescue
        transaction.run_on_failure_callbacks
        raise
      else
        transaction.commit
      end
    end

    def initialize
      @actions = []
    end

    def commit
      actions_to_commit = @actions.reject(&:aborted?).reject(&:skip?)
      return if actions_to_commit.empty?

      action_requests = actions_to_commit.map(&:action_request)
      Dynamoid.adapter.transact_write_items(action_requests)
      actions_to_commit.each(&:on_completing)

      nil
    rescue Aws::Errors::ServiceError
      run_on_failure_callbacks
      raise
    end

    def run_on_failure_callbacks
      actions_to_commit = @actions.reject(&:aborted?).reject(&:skip?)
      actions_to_commit.each(&:on_failure)
    end

    def save!(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_error: true)
      register_action action
    end

    def save(model, **options)
      action = Dynamoid::TransactionWrite::Save.new(model, **options, raise_error: false)
      register_action action
    end

    def create!(model_class, attributes = {}, &block)
      if attributes.is_a? Array
        attributes.map do |attr|
          action = Dynamoid::TransactionWrite::Create.new(model_class, attr, raise_error: true, &block)
          register_action action
        end
      else
        action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_error: true, &block)
        register_action action
      end
    end

    def create(model_class, attributes = {}, &block)
      if attributes.is_a? Array
        attributes.map do |attr|
          action = Dynamoid::TransactionWrite::Create.new(model_class, attr, raise_error: false, &block)
          register_action action
        end
      else
        action = Dynamoid::TransactionWrite::Create.new(model_class, attributes, raise_error: false, &block)
        register_action action
      end
    end

    def upsert(model_class, hash_key, range_key = nil, attributes) # rubocop:disable Style/OptionalArguments
      action = Dynamoid::TransactionWrite::Upsert.new(model_class, hash_key, range_key, attributes)
      register_action action
    end

    def update_fields(model_class, hash_key, range_key = nil, attributes) # rubocop:disable Style/OptionalArguments
      action = Dynamoid::TransactionWrite::UpdateFields.new(model_class, hash_key, range_key, attributes)
      register_action action
    end

    def update_attributes(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_error: false)
      register_action action
    end

    def update_attributes!(model, attributes)
      action = Dynamoid::TransactionWrite::UpdateAttributes.new(model, attributes, raise_error: true)
      register_action action
    end

    def delete(model_or_model_class, hash_key = nil, range_key = nil)
      action = if model_or_model_class.is_a? Class
                 Dynamoid::TransactionWrite::DeleteWithPrimaryKey.new(model_or_model_class, hash_key, range_key)
               else
                 Dynamoid::TransactionWrite::DeleteWithInstance.new(model_or_model_class)
               end
      register_action action
    end

    def destroy!(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model, raise_error: true)
      register_action action
    end

    def destroy(model)
      action = Dynamoid::TransactionWrite::Destroy.new(model, raise_error: false)
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
