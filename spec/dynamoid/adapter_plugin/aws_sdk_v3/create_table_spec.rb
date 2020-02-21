# frozen_string_literal: true

require 'dynamoid/adapter_plugin/aws_sdk_v3/create_table'
require 'spec_helper'

describe Dynamoid::AdapterPlugin::AwsSdkV3::CreateTable do
  let(:client) { double('client') }
  let(:options) do
    {
      hash_key_type: :string,
      billing_mode: :provisioned,
      read_capacity: 50,
      write_capacity: 10
    }
  end
  let(:response) { double('response', table_description: table_description) }
  let(:table_description) { double('table_description', table_status: 'ACTIVE') }

  describe 'call' do
    context 'table properties' do
      it 'has the correct table name' do
        expect(client).to receive(:create_table)
          .with(hash_including(table_name: :dogs))
          .and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      it 'defines the billing mode' do
        expect(client).to receive(:create_table)
          .with(hash_including(billing_mode: 'PROVISIONED'))
          .and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      it 'defines the read and write capacity' do
        expect(client).to receive(:create_table)
          .with(hash_including(provisioned_throughput: { read_capacity_units: 50, write_capacity_units: 10 }))
          .and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      context 'on demand' do
        let(:options) do
          { billing_mode: :on_demand }
        end

        it 'defines the billing mode as PAY_PER_REQUEST' do
          expect(client).to receive(:create_table)
            .with(hash_including(billing_mode: 'PAY_PER_REQUEST'))
            .and_return(response)

          described_class.new(client, :dogs, :id, options).call
        end

        it 'does not define read and write capacity' do
          expect(client).to receive(:create_table)
            .with(hash_excluding(:provisioned_throughput))
            .and_return(response)

          described_class.new(client, :dogs, :id, options).call
        end
      end
    end

    context 'key schema' do
      it 'defines a simple primary key' do
        expect(client).to receive(:create_table)
          .with(hash_including(key_schema: [hash_including(attribute_name: 'id', key_type: 'HASH')]))

        described_class.new(client, :dogs, :id, options).call
      end

      it 'defines the primary key attribute' do
        expect(client).to receive(:create_table)
          .with(hash_including(attribute_definitions: [hash_including(attribute_name: 'id', attribute_type: 'S')]))
          .and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      it 'defines a composite primary key' do
        expect(client).to receive(:create_table)
          .with(
            hash_including(
              key_schema: [
                hash_including(attribute_name: 'id', key_type: 'HASH'),
                hash_including(attribute_name: 'name', key_type: 'RANGE')
              ]
            )
          ).and_return(response)

        described_class.new(client, :dogs, :id, range_key: { name: :string }).call
      end

      it 'defines the composite key attributes' do
        expect(client).to receive(:create_table)
          .with(
            hash_including(
              attribute_definitions: [
                hash_including(attribute_name: 'id', attribute_type: 'S'),
                hash_including(attribute_name: 'name', attribute_type: 'S')
              ]
            )
          ).and_return(response)

        described_class.new(client, :dogs, :id, hash_key_type: :string, range_key: { name: :string }).call
      end
    end

    context 'local secondary index' do
      let(:options) do
        super().merge(local_secondary_indexes: [index])
      end

      let(:index) do
        double('index', name: 'local', projection_type: :all, type: :local_secondary,
               hash_key_schema: hash_key_schema, range_key_schema: range_key_schema)
      end

      let(:hash_key_schema) do
        { type: :string }
      end

      let(:range_key_schema) do
        { id: :string }
      end

      it 'defines the index' do
        expect(client).to receive(:create_table)
          .with(
            hash_including(
              local_secondary_indexes: [
                hash_including(
                  index_name: 'local', key_schema: [
                    hash_including(attribute_name: 'type', key_type: 'HASH'),
                    hash_including(attribute_name: 'id', key_type: 'RANGE')
                  ]
                )
              ]
            )
          ).and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end
    end

    context 'global secondary index' do
      let(:options) do
        super().merge(global_secondary_indexes: [index])
      end

      let(:index) do
        double('index', name: 'global', projection_type: :all, type: :global_secondary,
               hash_key_schema: hash_key_schema, range_key_schema: range_key_schema,
               read_capacity: 20, write_capacity: 5)
      end

      let(:hash_key_schema) do
        { type: :string }
      end

      let(:range_key_schema) do
        { id: :string }
      end

      it 'defines the index' do
        expect(client).to receive(:create_table)
          .with(
            hash_including(
              global_secondary_indexes: [
                hash_including(
                  index_name: 'global', key_schema: [
                    hash_including(attribute_name: 'type', key_type: 'HASH'),
                    hash_including(attribute_name: 'id', key_type: 'RANGE')
                  ]
                )
              ]
            )
          ).and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      it 'defines the provisioned capacity' do
        expect(client).to receive(:create_table)
          .with(
            hash_including(
              global_secondary_indexes: [
                hash_including(provisioned_throughput: { read_capacity_units: 20, write_capacity_units: 5 })
              ]
            )
          ).and_return(response)

        described_class.new(client, :dogs, :id, options).call
      end

      context 'on demand' do
        let(:options) do
          super().merge(billing_mode: :on_demand)
        end

        it 'does not define a capacity' do
          expect(client).to receive(:create_table)
            .with(
              hash_including(
                global_secondary_indexes: [
                  hash_excluding(provisioned_throughput: { read_capacity_units: 20, write_capacity_units: 5 })
                ]
              )
            ).and_return(response)

          described_class.new(client, :dogs, :id, options).call
        end
      end
    end
  end
end
