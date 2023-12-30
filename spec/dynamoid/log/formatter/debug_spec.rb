# frozen_string_literal: true

require 'spec_helper'
require 'dynamoid/log/formatter'

describe Dynamoid::Log::Formatter::Debug do
  describe '#format' do
    let(:subject) { described_class.new }

    let(:logger) { Logger.new(buffer) }
    let(:buffer) { StringIO.new }

    let(:request) do
      <<~JSON
        {
          "TableName": "dynamoid_tests_items",
          "KeySchema": [
            {
              "AttributeName": "id",
              "KeyType": "HASH"
            }
          ],
          "AttributeDefinitions": [
            {
              "AttributeName": "id",
              "AttributeType": "S"
            }
          ],
          "BillingMode": "PROVISIONED",
          "ProvisionedThroughput": {
            "ReadCapacityUnits": 100,
            "WriteCapacityUnits": 20
          }
        }
      JSON
    end

    let(:response_pattern) do
      Regexp.compile <<~JSON
        \\{
          "TableDescription": \\{
            "AttributeDefinitions": \\[
              \\{
                "AttributeName": "id",
                "AttributeType": "S"
              \\}
            \\],
            "TableName": "dynamoid_tests_items",
            "KeySchema": \\[
              \\{
                "AttributeName": "id",
                "KeyType": "HASH"
              \\}
            \\],
            "TableStatus": "ACTIVE",
            "CreationDateTime": .+?,
            "ProvisionedThroughput": \\{
              "LastIncreaseDateTime": 0.0,
              "LastDecreaseDateTime": 0.0,
              "NumberOfDecreasesToday": 0,
              "ReadCapacityUnits": 100,
              "WriteCapacityUnits": 20
            \\},
            "TableSizeBytes": 0,
            "ItemCount": 0,
            "TableArn": ".+?",
            "DeletionProtectionEnabled": false
          \\}
        \\}
      JSON
    end

    before do
      @log_formatter = Dynamoid.config.log_formatter
      @logger = Dynamoid.config.logger

      Dynamoid.config.log_formatter = subject
      Dynamoid.config.logger = logger
      Dynamoid.adapter.connect!  # clear cached client
    end

    after do
      Dynamoid.config.log_formatter = @log_formatter
      Dynamoid.config.logger = @logger
      Dynamoid.adapter.connect!  # clear cached client
    end

    it 'logs request and response JSON body' do
      new_class(table_name: 'items').create_table

      expect(buffer.string).to include(request)
      expect(buffer.string).to match(response_pattern)
    end
  end
end
