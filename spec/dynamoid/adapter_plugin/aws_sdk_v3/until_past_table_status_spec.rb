# frozen_string_literal: true

require 'spec_helper'
require 'dynamoid/adapter_plugin/aws_sdk_v3'

describe Dynamoid::AdapterPlugin::AwsSdkV3::UntilPastTableStatus do
  describe 'call' do
    context 'table creation' do
      let(:client) { double('client') }
      let(:response_creating) { double('response#creating', table: creating_table) }
      let(:response_active) { double('response#active', table: active_table) }
      let(:creating_table) { double('creating_table', table_status: 'CREATING') }
      let(:active_table) { double('creating_table', table_status: 'ACTIVE') }

      it 'wait until table is created', config: { sync_retry_max_times: 60 } do
        expect(client).to receive(:describe_table)
          .with(table_name: :dogs).exactly(3).times
          .and_return(response_creating, response_creating, response_active)

        described_class.new(client, :dogs, :creating).call
      end

      it 'stops if exceeded Dynamoid.config.sync_retry_max_times attempts limit',
        config: { sync_retry_max_times: 5 } do

        expect(client).to receive(:describe_table)
          .exactly(6).times
          .and_return(*[response_creating]*6)

        described_class.new(client, :dogs, :creating).call
      end

      it 'uses :sync_retry_max_times seconds to delay attempts',
        config: { sync_retry_wait_seconds: 2, sync_retry_max_times: 3 } do

        service = described_class.new(client, :dogs, :creating)
        allow(client).to receive(:describe_table).and_return(response_creating).exactly(4).times
        expect(service).to receive(:sleep).with(2).exactly(4).times

        service.call
      end
    end
  end
end
