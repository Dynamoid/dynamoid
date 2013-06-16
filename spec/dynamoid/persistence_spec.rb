require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Persistence" do

  before do
    Random.stubs(:rand).with(Dynamoid::Config.partition_size).returns(0)
    @address = Address.new
  end

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid::Adapter.delete_table(Address.table_name) if Dynamoid::Adapter.list_tables.include?(Address.table_name)
      end

      it 'creates a table' do
        Address.create_table(:table_name => Address.table_name)

        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(:table_name => Address.table_name)

        Address.table_exists?(Address.table_name).should be_true
        Address.table_exists?('crazytable').should be_false
      end
    end
  end

  it 'assigns itself an id on save' do
    @address.save

    Dynamoid::Adapter.read("dynamoid_tests_addresses", @address.id)[:id].should == @address.id
  end
  
  it 'prevents concurrent writes to tables with a lock_version' do
    @address.save!
    a1 = @address
    a2 = Address.find(@address.id)
    
    a1.city = 'Seattle'
    a2.city = 'San Francisco'
    
    a1.save!
    expect { a2.save! }.to raise_exception(Dynamoid::Errors::ConditionalCheckFailedException)
  end
  
  configured_with 'partitioning' do
    it 'raises an error when attempting to use optimistic locking' do
      expect { address.save! }.to raise_exception
    end
  end
  
  it 'assigns itself an id on save only if it does not have one' do
    @address.id = 'test123'
    @address.save

    Dynamoid::Adapter.read("dynamoid_tests_addresses", 'test123').should_not be_empty
  end

  it 'has a table name' do
    Address.table_name.should == 'dynamoid_tests_addresses'
  end

  it 'saves indexes along with itself' do
    @user = User.new(:name => 'Josh')

    @user.expects(:save_indexes).once.returns(true)
    @user.save
  end

  it 'deletes an item completely' do
    @user = User.create(:name => 'Josh')
    @user.destroy

    Dynamoid::Adapter.read("dynamoid_tests_users", @user.id).should be_nil
  end

  it 'keeps string attributes as strings' do
    @user = User.new(:name => 'Josh')
    @user.send(:dump)[:name].should == 'Josh'
  end

  it 'dumps datetime attributes' do
    @user = User.create(:name => 'Josh')
    @user.send(:dump)[:name].should == 'Josh'
  end

  it 'dumps integer attributes' do
    @subscription = Subscription.create(:length => 10)
    @subscription.send(:dump)[:length].should == 10
  end

  it 'dumps set attributes' do
    @subscription = Subscription.create(:length => 10)
    @magazine = @subscription.magazine.create

    @subscription.send(:dump)[:magazine_ids].should == Set[@magazine.id]
  end

  it 'handles nil attributes properly' do
    Address.undump(nil).should be_a(Hash)
  end

  it 'dumps and undump a serialized field' do
    @address.options = (hash = {:x => [1, 2], "foobar" => 3.14})
    Address.undump(@address.send(:dump))[:options].should == hash
  end

  [true, false].each do |bool|
    it "dumps a #{bool} boolean field" do
      @address.deliverable = bool
      Address.undump(@address.send(:dump))[:deliverable].should == bool
    end
  end

  it 'raises on an invalid boolean value' do
    expect do
      @address.deliverable = true
      data = @address.send(:dump)
      data[:deliverable] = 'foo'
      Address.undump(data)
    end.to raise_error(ArgumentError)
  end

  it 'loads a hash into a serialized field' do
    hash = {foo: :bar}
    Address.new(options: hash).options.should == hash
  end

  it 'loads attributes from a hash' do
    @time = DateTime.now
    @hash = {:name => 'Josh', :created_at => @time.to_f}

    User.undump(@hash)[:name].should == 'Josh'
    User.undump(@hash)[:created_at].to_f == @time.to_f
  end

  it 'runs the before_create callback only once' do
    CamelCase.any_instance.expects(:doing_before_create).once.returns(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #create' do
    CamelCase.any_instance.expects(:doing_after_create).once.returns(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #save' do
    CamelCase.any_instance.expects(:doing_after_create).once.returns(true)

    CamelCase.new.save
  end

  it 'works with a HashWithIndifferentAccess' do
    hash = ActiveSupport::HashWithIndifferentAccess.new("city" => "Atlanta")

    lambda {Address.create(hash)}.should_not raise_error
  end

  context 'create' do
    {
      Tweet   => ['with range',    { :tweet_id => 1, :group => 'abc' }],
      Message => ['without range', { :message_id => 1, :text => 'foo', :time => DateTime.now }]
    }.each_pair do |clazz, fields|
      it "checks for existence of an existing object #{fields[0]}" do
        t1 = clazz.new(fields[1])
        t2 = clazz.new(fields[1])

        t1.save
        expect do
          t2.save!
        end.to raise_exception Dynamoid::Errors::ConditionalCheckFailedException
      end
    end
  end

  context 'unknown fields' do
    let(:clazz) do
      Class.new do
        include Dynamoid::Document
        table :name => :addresses

        field :city
        field :options, :serialized
        field :deliverable, :bad_type_specifier
      end
    end

    it 'raises when undumping a column with an unknown field type' do
      expect do
        clazz.new(:deliverable => true) #undump is called here
      end.to raise_error(ArgumentError)
    end

    it 'raises when dumping a column with an unknown field type' do
      doc = clazz.new
      doc.deliverable = true
      expect do
        doc.dump
      end.to raise_error(ArgumentError)
    end
  end

  context 'update' do

    before :each do
      @tweet = Tweet.create(:tweet_id => 1, :group => 'abc', :count => 5, :tags => ['db', 'sql'], :user_name => 'john')
    end

    it 'runs before_update callbacks when doing #update' do
      CamelCase.any_instance.expects(:doing_before_update).once.returns(true)

      CamelCase.create(:color => 'blue').update do |t|
        t.set(:color => 'red')
      end
    end

    it 'runs after_update callbacks when doing #update' do
      CamelCase.any_instance.expects(:doing_after_update).once.returns(true)

      CamelCase.create(:color => 'blue').update do |t|
        t.set(:color => 'red')
      end
    end

    it 'support add/delete operation on a field' do
      @tweet.update do |t|
        t.add(:count => 3)
        t.delete(:tags => ['db'])
      end

      @tweet.count.should eq(8)
      @tweet.tags.to_a.should eq(['sql'])
    end

    it 'checks the conditions on update' do
      @tweet.update(:if => { :count => 5 }) do |t|
        t.add(:count => 3)
      end.should be_true

      @tweet.count.should eq(8)

      @tweet.update(:if => { :count => 5 }) do |t|
        t.add(:count => 3)
      end.should be_false

      @tweet.count.should eq(8)

      expect {
        @tweet.update!(:if => { :count => 5 }) do |t|
          t.add(:count => 3)
        end
      }.to raise_error(Dynamoid::Errors::ConditionalCheckFailedException)
    end
    
    it 'prevents concurrent saves to tables with a lock_version' do
      @address.save!
      a2 = Address.find(@address.id)
      a2.update! { |a| a.set(:city => "Chicago") }
      
      expect do
        @address.city = "Seattle"
        @address.save!
      end.to raise_error(Dynamoid::Errors::ConditionalCheckFailedException)
    end

  end

  context 'delete' do
    it 'deletes model with datetime range key' do
      lambda {
        msg = Message.create!(:message_id => 1, :time => DateTime.now, :text => "Hell yeah")
        msg.destroy
      }.should_not raise_error
    end
  end
end
