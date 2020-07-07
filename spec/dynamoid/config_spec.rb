# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Config do
  describe 'credentials' do
    let(:credentials_new) do
      Aws::Credentials.new('your_access_key_id', 'your_secret_access_key')
    end

    before do
      @credentials_old = Dynamoid.config.credentials
      Dynamoid.config.credentials = credentials_new
      Dynamoid.adapter.connect!  # clear cached client
    end

    after do
      Dynamoid.config.credentials = @credentials_old
      Dynamoid.adapter.connect!  # clear cached client
    end

    it 'passes credentials to a client connection' do
      credentials = Dynamoid.adapter.client.config.credentials

      expect(credentials.access_key_id).to eq 'your_access_key_id'
      expect(credentials.secret_access_key).to eq 'your_secret_access_key'
    end
  end

  describe 'log_formatter' do
    let(:log_formatter) { Aws::Log::Formatter.short }
    let(:logger) { Logger.new(buffer) }
    let(:buffer) { StringIO.new }

    before do
      @log_formatter = Dynamoid.config.log_formatter
      @logger = Dynamoid.config.logger

      Dynamoid.config.log_formatter = log_formatter
      Dynamoid.config.logger = logger
      Dynamoid.adapter.connect!  # clear cached client
    end

    after do
      Dynamoid.config.log_formatter = @log_formatter
      Dynamoid.config.logger = @logger
      Dynamoid.adapter.connect!  # clear cached client
    end

    it 'changes logging format' do
      new_class.create_table
      expect(buffer.string).to match(/\[Aws::DynamoDB::Client 200 .+\] create_table \n/)
    end
  end
end
