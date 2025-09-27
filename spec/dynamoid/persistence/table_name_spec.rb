# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.create_table', remove_constants: %i[Payment Billing] do
    it 'uses generated table name when it is not specified' do
      class Payment # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        field :comment
      end

      expect(Payment.table_name).to eq('dynamoid_tests_payments')
    end

    it 'ignores an outer module name when class is nested into the one and a table name is not specified' do
      module Billing # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        class Payment # rubocop:disable RSpec/LeakyConstantDeclaration
          include Dynamoid::Document

          field :comment
        end
      end

      expect(Billing::Payment.table_name).to eq('dynamoid_tests_payments')
    end

    it 'uses given table name when it is specified' do
      class Payment # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        table name: :purchases
      end

      expect(Payment.table_name).to eq('dynamoid_tests_purchases')
    end

    it 'adds configured namespace', config: { namespace: 'billing' } do
      class Payment # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        table name: :purchases
      end

      expect(Payment.table_name).to eq('billing_purchases')
    end

    it 'ignores namespace if it is an empty String', config: { namespace: '' } do
      class Payment # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        table name: :purchases
      end

      expect(Payment.table_name).to eq('purchases')
    end

    it 'ignores namespace if it is nil', config: { namespace: nil } do
      class Payment # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        table name: :purchases
      end

      expect(Payment.table_name).to eq('purchases')
    end

    it 'uses given table ARN when it is specified', config: { create_table_on_save: false } do
      arn = 'arn:aws:dynamodb:ddblocal:000000000000:table/dynamoid_tests_purchases'

      Payment = Class.new do # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
        include Dynamoid::Document

        table arn: arn
        field :comment
      end

      expect(Payment.table_name).to eq(arn)
    end
  end
end
