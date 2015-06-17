require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Validations" do
  before do
    @document = Class.new do
      include Dynamoid::Document

      def self.name
        'Document'
      end
    end
  end

  it 'validates presence of' do
    @document.field :name
    @document.validates_presence_of :name
    doc = @document.new
    expect(doc.save).to be_falsey
    expect(doc.new_record).to be_truthy
    doc.name = 'secret'
    expect(doc.save).to_not be_falsey
    expect(doc.errors).to be_empty
  end

  it 'raises document not found' do
    @document.field :name
    @document.validates_presence_of :name
    doc = @document.new
    expect { doc.save! }.to raise_error(Dynamoid::Errors::DocumentNotValid)

    expect { @document.create! }.to raise_error(Dynamoid::Errors::DocumentNotValid)

    doc = @document.create!(:name => 'test')
    expect(doc.errors).to be_empty
  end
end
