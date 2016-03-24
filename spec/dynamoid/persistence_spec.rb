require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Persistence do
  let(:address) { Address.new }

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid.adapter.delete_table(Address.table_name) if Dynamoid.adapter.list_tables.include?(Address.table_name)
      end

      it 'creates a table' do
        Address.create_table(:table_name => Address.table_name)

        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(:table_name => Address.table_name)

        expect(Address.table_exists?(Address.table_name)).to be_truthy
        expect(Address.table_exists?('crazytable')).to be_falsey
      end
    end
  end

  it 'assigns itself an id on save' do
    address.save

    expect(Dynamoid.adapter.read("dynamoid_tests_addresses", address.id)[:id]).to eq address.id
  end

  it 'prevents concurrent writes to tables with a lock_version' do
    address.save!
    a1 = address
    a2 = Address.find(address.id)

    a1.city = 'Seattle'
    a2.city = 'San Francisco'

    a1.save!
    expect { a2.save! }.to raise_exception(Dynamoid::Errors::StaleObjectError)
  end

  it 'assigns itself an id on save only if it does not have one' do
    address.id = 'test123'
    address.save

    expect(Dynamoid.adapter.read("dynamoid_tests_addresses", 'test123')).to_not be_empty
  end

  it 'has a table name' do
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
  end

  context 'with namespace is empty' do
    def reload_address
      Object.send(:remove_const, 'Address')
      load 'app/models/address.rb'
    end

    namespace = Dynamoid::Config.namespace

    before do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = ""
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = namespace
      end
    end

    it 'does not add a namespace prefix to table names' do
      table_name = Address.table_name
      expect(Dynamoid::Config.namespace).to be_empty
      expect(table_name).to eq 'addresses'
    end
  end

  context 'with timestamps set to false' do
    def reload_address
      Object.send(:remove_const, 'Address')
      load 'app/models/address.rb'
    end

    timestamps = Dynamoid::Config.timestamps

    before do
      reload_address
      Dynamoid.configure do |config|
        config.timestamps = false
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.timestamps = timestamps
      end
    end

    it 'sets nil to created_at and updated_at' do
      address = Address.create
      expect(address.created_at).to be_nil
      expect(address.updated_at).to be_nil
    end
  end

  it 'deletes an item completely' do
    @user = User.create(:name => 'Josh')
    @user.destroy

    expect(Dynamoid.adapter.read("dynamoid_tests_users", @user.id)).to be_nil
  end

  it 'keeps string attributes as strings' do
    @user = User.new(:name => 'Josh')
    expect(@user.send(:dump)[:name]).to eq 'Josh'
  end

  it 'keeps raw Hash attributes as a Hash' do
    config = {:acres => 5, :trees => {:cyprus => 30, :poplar => 10, :joshua => 1}, :horses => ['Lucky', 'Dummy'], :lake => 1, :tennis_court => 1}
    @addr = Address.new(:config => config)
    expect(@addr.send(:dump)[:config]).to eq config
  end

  it 'keeps raw Array attributes as an Array' do
    config = ['windows', 'roof', 'doors']
    @addr = Address.new(:config => config)
    expect(@addr.send(:dump)[:config]).to eq config
  end

  it 'keeps raw String attributes as a String' do
    config = 'Configy'
    @addr = Address.new(:config => config)
    expect(@addr.send(:dump)[:config]).to eq config
  end

  it 'keeps raw Number attributes as a Number' do
    config = 100
    @addr = Address.new(:config => config)
    expect(@addr.send(:dump)[:config]).to eq config
  end

  it 'dumps datetime attributes' do
    @user = User.create(:name => 'Josh')
    expect(@user.send(:dump)[:name]).to eq 'Josh'
  end

  it 'dumps integer attributes' do
    @subscription = Subscription.create(:length => 10)
    expect(@subscription.send(:dump)[:length]).to eq 10
  end

  it 'dumps set attributes' do
    @subscription = Subscription.create(:length => 10)
    @magazine = @subscription.magazine.create

    expect(@subscription.send(:dump)[:magazine_ids]).to eq Set[@magazine.hash_key]
  end

  it 'handles nil attributes properly' do
    expect(Address.undump(nil)).to be_a(Hash)
  end

  it 'dumps and undump a serialized field' do
    address.options = (hash = {:x => [1, 2], "foobar" => 3.14})
    expect(Address.undump(address.send(:dump))[:options]).to eq hash
  end

  it 'dumps and undumps an integer in number field' do
    expect(Address.undump(Address.new(latitude: 123).send(:dump))[:latitude]).to eq 123
  end

  it 'dumps and undumps a float in number field' do
    expect(Address.undump(Address.new(latitude: 123.45).send(:dump))[:latitude]).to eq 123.45
  end

  it 'dumps and undumps a BigDecimal in number field' do
    expect(Address.undump(Address.new(latitude: BigDecimal.new(123.45, 3)).send(:dump))[:latitude]).to eq 123
  end

  it 'supports empty containers in `serialized` fields' do
    u = User.create(name: 'Philip')
    u.favorite_colors = Set.new
    u.save!

    u = User.find(u.id)
    expect(u.favorite_colors).to eq Set.new
  end

  it 'supports container types being nil' do
    u = User.create(name: 'Philip')
    u.todo_list = nil
    u.save!

    u = User.find(u.id)
    expect(u.todo_list).to be_nil
  end

  [true, false].each do |bool|
    it "dumps a #{bool} boolean field" do
      address.deliverable = bool
      expect(Address.undump(address.send(:dump))[:deliverable]).to eq bool
    end
  end

  it 'raises on an invalid boolean value' do
    expect do
      address.deliverable = true
      data = address.send(:dump)
      data[:deliverable] = 'foo'
      Address.undump(data)
    end.to raise_error(ArgumentError)
  end

  it 'loads a hash into a serialized field' do
    hash = {foo: :bar}
    expect(Address.new(options: hash).options).to eq hash
  end

  it 'loads attributes from a hash' do
    @time = DateTime.now
    @hash = {:name => 'Josh', :created_at => @time.to_f}

    expect(User.undump(@hash)[:name]).to eq 'Josh'
    User.undump(@hash)[:created_at].to_f == @time.to_f
  end

  it 'runs the before_create callback only once' do
    expect_any_instance_of(CamelCase).to receive(:doing_before_create).once.and_return(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #create' do
    expect_any_instance_of(CamelCase).to receive(:doing_after_create).once.and_return(true)

    CamelCase.create
  end

  it 'runs after save callbacks when doing #save' do
    expect_any_instance_of(CamelCase).to receive(:doing_after_create).once.and_return(true)

    CamelCase.new.save
  end

  it 'works with a HashWithIndifferentAccess' do
    hash = ActiveSupport::HashWithIndifferentAccess.new("city" => "Atlanta")

    expect{Address.create(hash)}.to_not raise_error
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
        end.to raise_exception Dynamoid::Errors::RecordNotUnique
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
      @tweet = Tweet.create(:tweet_id => 1, :group => 'abc', :count => 5, :tags => Set.new(['db', 'sql']), :user_name => 'john')
    end

    it 'runs before_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_before_update).once.and_return(true)

      CamelCase.create(:color => 'blue').update do |t|
        t.set(:color => 'red')
      end
    end

    it 'runs after_update callbacks when doing #update' do
      expect_any_instance_of(CamelCase).to receive(:doing_after_update).once.and_return(true)

      CamelCase.create(:color => 'blue').update do |t|
        t.set(:color => 'red')
      end
    end

    it 'support add/delete operation on a field' do
      @tweet.update do |t|
        t.add(:count => 3)
        t.delete(:tags => Set.new(['db']))
      end

      expect(@tweet.count).to eq(8)
      expect(@tweet.tags.to_a).to eq(['sql'])
    end

    it 'checks the conditions on update' do
      result = @tweet.update(:if => { :count => 5 }) do |t|
        t.add(:count => 3)
      end
      expect(result).to be_truthy

      expect(@tweet.count).to eq(8)

      result = @tweet.update(:if => { :count => 5 }) do |t|
        t.add(:count => 3)
      end
      expect(result).to be_falsey

      expect(@tweet.count).to eq(8)

      expect do
        @tweet.update!(:if => { :count => 5 }) do |t|
          t.add(:count => 3)
        end
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

    it 'prevents concurrent saves to tables with a lock_version' do
      address.save!
      a2 = Address.find(address.id)
      a2.update! { |a| a.set(:city => "Chicago") }

      expect do
        address.city = "Seattle"
        address.save!
      end.to raise_error(Dynamoid::Errors::StaleObjectError)
    end

  end

  context 'delete' do
    it 'deletes model with datetime range key' do
      expect do
        msg = Message.create!(:message_id => 1, :time => DateTime.now, :text => "Hell yeah")
        msg.destroy
      end.to_not raise_error
    end

    context 'with lock version' do
      it 'deletes a record if lock version matches' do
        address.save!
        expect { address.destroy }.to_not raise_error
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.destroy }.to raise_exception(Dynamoid::Errors::StaleObjectError)
      end

      it 'uses the correct lock_version even if it is modified' do
        address.save!
        a1 = address
        a1.lock_version = 100

        expect { a1.destroy }.to_not raise_error
      end
    end
  end

  context 'single table inheritance' do
    let(:car) { Car.create(power_locks: false) }
    let(:sub) { NuclearSubmarine.create(torpedoes: 5) }

    it 'saves subclass objects in the parent table' do
      c = car
      expect(Vehicle.find(c.id)).to eq c
    end

    it 'loads subclass item when querying the parent table' do
      c = car
      s = sub

      Vehicle.all.to_a.tap { |v|
        expect(v).to include(c)
        expect(v).to include(s)
      }
    end
  end

  describe ':raw datatype persistence' do
    subject { Address.new() }

    it 'it persists raw Hash and reads the same back' do
      config = {:acres => 5, :trees => {:cyprus => 30, :poplar => 10, :joshua => 1}, :horses => ['Lucky', 'Dummy'], :lake => 1, :tennis_court => 1}
      subject.config = config
      subject.save!
      subject.reload
      expect(subject.config).to eq config
    end

    it 'it persists raw Array and reads the same back' do
      config = ['windows', 'doors', 'roof']
      subject.config = config
      subject.save!
      subject.reload
      expect(subject.config).to eq config
    end

    it 'it persists raw Number and reads the same back' do
      config = 100
      subject.config = config
      subject.save!
      subject.reload
      expect(subject.config).to eq config
    end

    it 'it persists raw String and reads the same back' do
      config = 'Configy'
      subject.config = config
      subject.save!
      subject.reload
      expect(subject.config).to eq config
    end

    it 'it persists raw value, then reads back, then deletes the value by setting to nil, persists and reads the nil back' do
      config = 'To become nil'
      subject.config = config
      subject.save!
      subject.reload
      expect(subject.config).to eq config

      subject.config = nil
      subject.save!
      subject.reload
      expect(subject.config).to be_nil
    end
  end

  describe 'class-type fields' do
    subject { doc_class.new }

    context 'when Money can load itself and Money instances can dump themselves with Dynamoid-specific methods' do
      let(:doc_class) do
        Class.new do
          def self.name; 'Doc'; end

          include Dynamoid::Document

          field :price, MoneyInstanceDump
        end
      end

      before(:each) do
        subject.price = MoneyInstanceDump.new(BigDecimal.new('5'))
        subject.save!
      end

      it 'round-trips using Dynamoid-specific methods' do
        expect(doc_class.all.first).to eq subject
      end

      it 'is findable as a string' do
        expect(doc_class.where(price: '5.0').first).to eq subject
      end
    end

    context 'when MoneyAdapter dumps/loads a class that does not directly support Dynamoid\'s interface' do
      let(:doc_class) do
        Class.new do
          def self.name; 'Doc'; end

          include Dynamoid::Document

          field :price, MoneyAdapter
        end
      end

      before(:each) do
        subject.price = Money.new(BigDecimal.new('5'))
        subject.save!
        subject.reload
      end

      it 'round-trips using Dynamoid-specific methods' do
        expect(doc_class.all.first.price).to eq subject.price
      end

      it 'is findable as a string' do
        expect(doc_class.where(price: '5.0').first).to eq subject
      end

      it 'is a Money object' do
        expect(subject.price).to be_a Money
      end
    end

    context 'when Money has Dynamoid-specific serialization methods and is a range' do
      let(:doc_class) do
        Class.new do
          def self.name; 'Doc'; end

          include Dynamoid::Document

          range :price, MoneyAsNumber
        end
      end

      before(:each) do
        subject.price = MoneyAsNumber.new(BigDecimal.new('5'))
        subject.save!
      end

      it 'round-trips using Dynamoid-specific methods' do
        expect(doc_class.all.first.price).to eq subject.price
      end

      it 'is findable with number semantics' do
        # With the primary key, we're forcing a Query rather than a Scan because of https://github.com/Dynamoid/Dynamoid/issues/6
        primary_key = subject.id
        expect(doc_class.where(id: primary_key).where('price.gt' => 4).first).to_not be_nil
      end
    end
  end
end
