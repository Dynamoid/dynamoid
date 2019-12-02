require 'spec_helper'

describe Dynamoid::Config do
  describe 'credentials' do
    let(:credentials_new) do
      Aws::Credentials.new('your_access_key_id', 'your_secret_access_key')
    end

    before do
      @credentials_old, Dynamoid.config.credentials = Dynamoid.config.credentials, credentials_new
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
end
