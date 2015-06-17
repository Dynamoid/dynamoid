require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Fields" do

  before do
    @address = Address.new
  end

  it 'declares read attributes' do
    expect(@address.city).to be_nil
  end

  it 'declares write attributes' do
    @address.city = 'Chicago'
    expect(@address.city).to eq 'Chicago'
  end

  it 'declares a query attribute' do
    expect(@address.city?).to be_falsey

    @address.city = 'Chicago'

    expect(@address.city?).to be_truthy
  end

  it 'automatically declares id' do
    expect{@address.id}.to_not raise_error
  end

  it 'automatically declares and fills in created_at and updated_at' do
    @address.save

    @address = @address.reload
    expect(@address.created_at).to_not be_nil
    expect(@address.created_at).to be_a DateTime
    expect(@address.updated_at).to_not be_nil
    expect(@address.updated_at).to be_a DateTime
  end

  context 'with a saved address' do
    before do
      @address = Address.create(:deliverable => true)
      @original_id = @address.id
    end

    it 'should write an attribute correctly' do
      @address.write_attribute(:city, 'Chicago')
    end

    it 'should write an attribute with an alias' do
      @address[:city] = 'Chicago'
    end

    it 'should read a written attribute' do
      @address.write_attribute(:city, 'Chicago')
      expect(@address.read_attribute(:city)).to eq 'Chicago'
    end

    it 'should read a written attribute with the alias' do
      @address.write_attribute(:city, 'Chicago')
      expect(@address[:city]).to eq 'Chicago'
    end

    it 'should update all attributes' do
      expect(@address).to receive(:save).once.and_return(true)
      @address.update_attributes(:city => 'Chicago')
      expect(@address[:city]).to eq 'Chicago'
      expect(@address.id).to eq @original_id
    end

    it 'should update one attribute' do
      expect(@address).to receive(:save).once.and_return(true)
      @address.update_attribute(:city, 'Chicago')
      expect(@address[:city]).to eq 'Chicago'
      expect(@address.id).to eq @original_id
    end

    it 'should update only created_at when no params are passed' do
      @initial_updated_at = @address.updated_at
      @address.update_attributes([])
      expect(@address.updated_at).to_not eq @initial_updated_at
    end

    it 'adds in dirty methods for attributes' do
      @address.city = 'Chicago'
      @address.save

      @address.city = 'San Francisco'

      expect(@address.city_was).to eq 'Chicago'
    end

    it 'returns all attributes' do
      expect(Address.attributes).to eq({:id=>{:type=>:string}, :created_at=>{:type=>:datetime}, :updated_at=>{:type=>:datetime}, :city=>{:type=>:string}, :options=>{:type=>:serialized}, :deliverable => {:type => :boolean}, :lock_version => {:type => :integer}})
    end
  end

  it "gives a warning when setting a single value larger than the maximum item size" do
    expect(Dynamoid.logger).to receive(:warn) do |input|
      expect(input).to include "city field has a length of 66000"
    end
    Address.new city: ("Ten chars " * 6_600)
  end

  context '.remove_attribute' do
    subject { @address }
    before(:each) do
      Address.field :foobar
      Address.remove_field :foobar
    end

    it 'should not be in the attributes hash' do
      expect(Address.attributes).to_not have_key(:foobar)
    end

    it 'removes the accessor' do
      expect(subject).to_not respond_to(:foobar)
    end

    it 'removes the writer' do
      expect(subject).to_not respond_to(:foobar=)
    end

    it 'removes the interrogative' do
      expect(subject).to_not respond_to(:foobar?)
    end
  end

  context 'default values for fields' do
    before do
      @clazz = Class.new do
        include Dynamoid::Document

        field :name, :string, :default => 'x'
        field :uid, :integer, :default => lambda { 42 }

        def self.name
          'Document'
        end
      end


      @doc = @clazz.new
    end

    it 'returns default value' do
      expect(@doc.name).to eq('x')
      expect(@doc.uid).to eq(42)
    end

    it 'should save default value' do
      @doc.save!
      expect(@doc.reload.name).to eq('x')
      expect(@doc.uid).to eq(42)
    end
  end

  context 'single table inheritance' do
    it "has only base class fields on the base class" do
      expect(Vehicle.attributes.keys.to_set).to eq Set.new([:type, :description, :created_at, :updated_at, :id])
    end

    it "has only the base and derived fields on a sub-class" do
      #Only NuclearSubmarines have torpedoes
      expect(Car.attributes).to_not have_key(:torpedoes)
    end
  end

end
