require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Fields" do

  before do
    @address = Address.new
  end

  it 'declares read attributes' do
    @address.city.should be_nil
  end

  it 'declares write attributes' do
    @address.city = 'Chicago'
    @address.city.should == 'Chicago'
  end

  it 'declares a query attribute' do
    @address.city?.should be_false

    @address.city = 'Chicago'

    @address.city?.should be_true
  end

  it 'automatically declares id' do
    lambda {@address.id}.should_not raise_error
  end

  it 'automatically declares and fills in created_at and updated_at' do
    @address.save

    @address = @address.reload
    @address.created_at.should_not be_nil
    @address.created_at.class.should == DateTime
    @address.updated_at.should_not be_nil
    @address.updated_at.class.should == DateTime
  end

  context 'with a saved address' do
    before do
      @address = Address.create
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
      @address.read_attribute(:city).should == 'Chicago'
    end

    it 'should read a written attribute with the alias' do
      @address.write_attribute(:city, 'Chicago')
      @address[:city].should == 'Chicago'
    end

    it 'should update all attributes' do
      @address.expects(:save).once.returns(true)
      @address.update_attributes(:city => 'Chicago')
      @address[:city].should == 'Chicago'
      @address.id.should == @original_id
    end

    it 'should update one attribute' do
      @address.expects(:save).once.returns(true)
      @address.update_attribute(:city, 'Chicago')
      @address[:city].should == 'Chicago'
      @address.id.should == @original_id
    end

    it 'adds in dirty methods for attributes' do
      @address.city = 'Chicago'
      @address.save

      @address.city = 'San Francisco'

      @address.city_was.should == 'Chicago'
    end

    it 'returns all attributes' do
      Address.attributes.should == {:id=>{:type=>:string}, :created_at=>{:type=>:datetime}, :updated_at=>{:type=>:datetime}, :city=>{:type=>:string}, :options=>{:type=>:serialized}}
    end
  end

  it "gives a warning when setting a single value larger than the maximum item size" do
    Dynamoid.logger.expects(:warn).with(regexp_matches(/city field has a length of 66000/))
    Address.new city: ("Ten chars " * 6_600)
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
      @doc.name.should eq('x')
      @doc.uid.should eq(42)
    end

    it 'should save default value' do
      @doc.save!
      @doc.reload.name.should eq('x')
      @doc.uid.should eq(42)
    end
  end

end
