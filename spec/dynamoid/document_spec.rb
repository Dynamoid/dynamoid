require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Document do

  it 'initializes a new document' do
    address = Address.new

    expect(address.new_record).to be_truthy
    expect(address.attributes).to eq({id: nil,
                                      created_at: nil,
                                      updated_at: nil,
                                      city: nil,
                                      options: nil,
                                      deliverable: nil,
                                      latitude: nil,
                                      config: nil,
                                      lock_version: nil})
  end

  it 'responds to will_change! methods for all fields' do
    address = Address.new
    expect(address).to respond_to(:id_will_change!)
    expect(address).to respond_to(:options_will_change!)
    expect(address).to respond_to(:created_at_will_change!)
    expect(address).to respond_to(:updated_at_will_change!)
  end

  it 'initializes a new document with attributes' do
    address = Address.new(:city => 'Chicago')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq({id: nil,
                                      created_at: nil,
                                      updated_at: nil,
                                      city: 'Chicago',
                                      options: nil,
                                      deliverable: nil,
                                      latitude: nil,
                                      config: nil,
                                      lock_version: nil})
  end

  it 'initializes a new document with a virtual attribute' do
    address = Address.new(:zip_code => '12345')

    expect(address.new_record).to be_truthy

    expect(address.attributes).to eq({id: nil,
                                      created_at: nil,
                                      updated_at: nil,
                                      city: 'Chicago',
                                      options: nil,
                                      deliverable: nil,
                                      latitude: nil,
                                      config: nil,
                                      lock_version: nil})
  end

  it 'allows interception of write_attribute on load' do
    class Model
      include Dynamoid::Document
      field :city
      def city=(value); self[:city] = value.downcase; end
    end
    expect(Model.new(:city => "Chicago").city).to eq "chicago"
  end

  it 'ignores unknown fields (does not raise error)' do
    class Model
      include Dynamoid::Document
      field :city
    end

    model = Model.new(:unknown_field => "test", :city => "Chicago")
    expect(model.city).to eql "Chicago"
  end

  it 'creates a new document' do
    address = Address.create(:city => 'Chicago')

    expect(address.new_record).to be_falsey
    expect(address.id).to_not be_nil
  end

  it 'knows if a document exists or not' do
    address = Address.create(:city => 'Chicago')
    expect(Address.exists?(address.id)).to be_truthy
    expect(Address.exists?("does-not-exist")).to be_falsey
    expect(Address.exists?(:city => address.city)).to be_truthy
    expect(Address.exists?(:city => "does-not-exist")).to be_falsey
  end

  it 'gets errors courtesy of ActiveModel' do
    address = Address.create(:city => 'Chicago')

    expect(address.errors).to be_empty
    expect(address.errors.full_messages).to be_empty
  end

  context '.reload' do
    let(:address){ Address.create }
    let(:message){ Message.create({:text => 'Nice, supporting datetime range!', :time => Time.now.to_datetime}) }
    let(:tweet){ tweet = Tweet.create(:tweet_id => 'x', :group => 'abc') }

    it 'reflects persisted changes' do
      address.update_attributes(:city => 'Chicago')
      expect(address.reload.city).to eq 'Chicago'
    end

    it 'uses a :consistent_read' do
      expect(Tweet).to receive(:find).with(tweet.hash_key, {:range_key => tweet.range_value, :consistent_read => true}).and_return(tweet)
      tweet.reload
    end

    it 'works with range key' do
      expect(tweet.reload.group).to eq 'abc'
    end

    it 'works with a :datetime range key' do
      expect { message.reload }.to_not raise_error
    end
  end

  it 'has default table options' do
    address = Address.create

    expect(address.id).to_not be_nil
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
    expect(Address.hash_key).to eq :id
    expect(Address.read_capacity).to eq 100
    expect(Address.write_capacity).to eq 20
  end

  it 'follows any table options provided to it' do
    tweet = Tweet.create(:group => 12345)

    expect{tweet.id}.to raise_error(NoMethodError)
    expect(tweet.tweet_id).to_not be_nil
    expect(Tweet.table_name).to eq 'dynamoid_tests_twitters'
    expect(Tweet.hash_key).to eq :tweet_id
    expect(Tweet.read_capacity).to eq 200
    expect(Tweet.write_capacity).to eq 200
  end

  shared_examples 'it has equality testing and hashing' do
    it 'is equal to itself' do
      expect(document).to eq document
    end

    it 'is equal to another document with the same key(s)' do
      expect(document).to eq same
    end

    it 'is not equal to another document with different key(s)' do
      expect(document).to_not eq different
    end

    it 'is not equal to an object that is not a document' do
      expect(document).to_not eq 'test'
    end

    it 'is not equal to nil' do
      expect(document).to_not eq nil
    end

    it 'hashes documents with the keys to the same value' do
      expect({document => 1}).to have_key(same)
    end
  end

  context 'without a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document) { Address.create(id: 123, city: 'Seattle') }
      let(:different) { Address.create(id: 456, city: 'Seattle') }
      let(:same) { Address.new(id: 123, city: 'Boston') }
    end
  end

  context 'with a range key' do
    it_behaves_like 'it has equality testing and hashing' do
      let(:document){ Tweet.create(:tweet_id => 'x', :group => 'abc', :msg => 'foo') }
      let(:different) { Tweet.create(:tweet_id => 'y', :group => 'abc', :msg => 'foo') }
      let(:same) { Tweet.new(:tweet_id => 'x', :group => 'abc', :msg => 'bar') }
    end

    it 'is not equal to another document with the same hash key but a different range value' do
      document = Tweet.create(:tweet_id => 'x', :group => 'abc')
      different = Tweet.create(:tweet_id => 'x', :group => 'xyz')

      expect(document).to_not eq different
    end
  end

  context 'single table inheritance' do
    it "should have a type" do
      expect(Vehicle.new.type).to eq "Vehicle"
    end

    it "reports the same table name for both base and derived classes" do
      expect(Vehicle.table_name).to eq Car.table_name
      expect(Vehicle.table_name).to eq NuclearSubmarine.table_name
    end
  end

  context '#count' do
    it 'returns the number of documents in the table' do
      document = Tweet.create(:tweet_id => 'x', :group => 'abc')
      different = Tweet.create(:tweet_id => 'x', :group => 'xyz')

      expect(Tweet.count).to eq 2
    end
  end
end
