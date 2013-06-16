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

    it 'should update only created_at when no params are passed' do
      @initial_updated_at = @address.updated_at
      @address.update_attributes([])
      @address.updated_at.should_not == @initial_updated_at
    end

    it 'adds in dirty methods for attributes' do
      @address.city = 'Chicago'
      @address.save

      @address.city = 'San Francisco'

      @address.city_was.should == 'Chicago'
    end

    it 'returns all attributes' do
      Address.attributes.should == {:id=>{:type=>:string}, :created_at=>{:type=>:datetime}, :updated_at=>{:type=>:datetime}, :city=>{:type=>:string}, :options=>{:type=>:serialized}, :deliverable => {:type => :boolean}, :lock_version => {:type => :integer}}
    end
  end

  it "gives a warning when setting a single value larger than the maximum item size" do
    Dynamoid.logger.expects(:warn).with(regexp_matches(/city field has a length of 66000/))
    Address.new city: ("Ten chars " * 6_600)
  end

  context '.remove_attribute' do
    subject { @address }
    before(:each) do
      Address.field :foobar
      Address.remove_field :foobar
    end

    it('should not be in the attributes hash') { Address.attributes.should_not have_key(:foobar) }
    it('removes the accessor') { should_not respond_to(:foobar)  }
    it('removes the writer')   { should_not respond_to(:foobar=) }
    it('removes the interrogative') { should_not respond_to(:foobar?) }
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

  context 'single table inheritance' do
    it "has only base class fields on the base class" do
      Vehicle.attributes.keys.to_set.should == Set.new([:type, :description, :created_at, :updated_at, :id])
    end

    it "has only the base and derived fields on a sub-class" do
      #Only NuclearSubmarines have torpedoes
      Car.attributes.should_not have_key(:torpedoes)
    end
  end

end
