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

  describe 'http_proxy' do
    let(:http_proxy) { nil }

    before do
      @http_proxy_old = Dynamoid.config.http_proxy
      Dynamoid.config.http_proxy = http_proxy
      Dynamoid.adapter.connect!  # clear cached client
    end

    after do
      Dynamoid.config.http_proxy = @http_proxy_old
      Dynamoid.adapter.connect!  # clear cached client
    end

    it 'is nil by default' do
      Dynamoid.config.reset_http_proxy
      expect(Dynamoid.config.http_proxy).to be_nil
    end

    context 'when String is provided' do
      let(:http_proxy) { 'http://localhost:8080' }

      it 'passes http_proxy to a client connection' do
        expect(Dynamoid.adapter.client.config.http_proxy).to eq 'http://localhost:8080'
      end
    end

    context 'when URI is provided' do
      let(:http_proxy) { URI.parse('http://localhost:8080') }

      it 'passes http_proxy URI to a client connection' do
        expect(Dynamoid.adapter.client.config.http_proxy).to eq URI.parse('http://localhost:8080')
      end
    end
  end

  describe 'use_yaml_unsafe_load' do
    before do
      @use_yaml_unsafe_load_old = Dynamoid.config.use_yaml_unsafe_load
    end

    after do
      Dynamoid.config.use_yaml_unsafe_load = @use_yaml_unsafe_load_old
    end

    if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.0')
      it 'is true by default' do
        expect(Dynamoid.config.use_yaml_unsafe_load).to be true
      end
    else
      it 'is false by default' do
        expect(Dynamoid.config.use_yaml_unsafe_load).to be false
      end
    end

    it 'can be changed' do
      Dynamoid.config.use_yaml_unsafe_load = true
      expect(Dynamoid.config.use_yaml_unsafe_load).to be true
    end
  end

  describe 'yaml_permitted_classes' do
    before do
      @yaml_permitted_classes_old = Dynamoid.config.yaml_permitted_classes
    end

    after do
      Dynamoid.config.yaml_permitted_classes = @yaml_permitted_classes_old
    end

    it 'is [Symbol, Set, Date, Time, DateTime] by default' do
      expect(Dynamoid.config.yaml_permitted_classes).to eq [Symbol, Set, Date, Time, DateTime]
    end

    it 'can be changed' do
      Dynamoid.config.yaml_permitted_classes = [Symbol, Range]
      expect(Dynamoid.config.yaml_permitted_classes).to eq [Symbol, Range]
    end
  end
end
