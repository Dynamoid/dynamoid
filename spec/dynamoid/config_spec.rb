require 'spec_helper'

describe Dynamoid::Config do
  describe 'credentials' do
    it 'passes credentials to a client connection', config: {
      credentials: Aws::Credentials.new('your_access_key_id', 'your_secret_access_key')
    } do
      credentials = Dynamoid.adapter.client.config.credentials

      expect(credentials.access_key_id).to eq 'your_access_key_id'
      expect(credentials.secret_access_key).to eq 'your_secret_access_key'
    end
  end
end
